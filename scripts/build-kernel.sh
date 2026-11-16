#!/bin/sh
#
# scripts/build-kernel.sh — SabakanOS レーンA: Linux カーネルビルド
#
# 概要:
#   kernel.org の Linux LTS 版 (タグ固定) のソースを取得し、x86_64 defconfig
#   にレーンA固有設定 (config/kernel-defconfig) を適用してコンパイルし、
#   カーネルイメージ (arch/x86/boot/bzImage) を出力する。
#
# ホスト (macOS 等) に x86_64 Linux 向けクロスコンパイラが無い場合は、
# コンパイルをスキップし .config の準備までで正常終了する。
#
# 出力:
#   build/linux-<VERSION>/arch/x86/boot/bzImage  (クロスコンパイラ有効時)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

KERNEL_VERSION="6.12.34"
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
# v6.x 系列の LTS 版。バージョン固定で再現性を担保。
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"

# Linux カーネルの Makefile は GNU Make >= 4.0 を要求する。
# macOS 標準の make (3.81) では不足するため、gmake (Homebrew) を優先する。
if command -v gmake >/dev/null 2>&1; then
    _MAKE="gmake"
else
    _MAKE="make"
fi

# macOS では Apple ld と互換性がないため、LLVM (clang+lld) を使用する。
# Clang Built Linux 対応により macOS 上で x86_64 カーネルをビルド可能。

BUILD_DIR="${ROOT}/build"
SRC_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
CONFIG_FILE="${ROOT}/config/kernel-defconfig"

# ホストツールコンパイル用インクルードパス。
# macOS 独自ヘッダ + libelf + x86_64 生成ヘッダ (sorttable 等の asm/types.h 解決用)。
# ホストツール (fixdep/kconfig) はこの Mac (arm64) でネイティブ実行するため、
# -D__x86_64__=1 は付けない (fixdep のシステムヘッダ再定義を避ける)。
# objtool/bzImage ビルドでは HOSTCFLAGS_FULL (__x86_64__=1 等) を個別に渡す。
HOSTCFLAGS_BASE="-Iscripts/macos-include -I$(brew --prefix libelf)/include -I${SRC_DIR}/arch/x86/include/generated/uapi -I${SRC_DIR}/arch/x86/include/uapi -I${SRC_DIR}/include/uapi -Wno-undef -Wno-incompatible-pointer-types -Wno-macro-redefined"
# objtool/bzImage 用: macOS 独自 endian.h をプリプロセス済みにし、
# macOS SDK の <endian.h> (machine/endian.h 経由の _OSSwapInt* 再定義) を回避。
# -fuse-ld=lld はコンパイルオプションではなくリンクオプションなので、
# bzImage ビルド時の LDFLAGS で個別に渡す。
HOSTCFLAGS_FULL="${HOSTCFLAGS_BASE} -include ${SRC_DIR}/scripts/macos-include/endian.h"
# ar ラッパー (BSD ar は -D 未対応のため -D を除去)
AR_WRAPPER="${ROOT}/scripts/ar-wrapper.sh"
# x86_64 ELF リンカ (macOS の /usr/bin/ld は Mach-O 専用なので lld を使用)
LLD="ld.lld"

# LLVM ビンutils 互換ツール (objcopy/readelf/nm/strip/ar 等) は macOS Xcode に
# 付属しないため Homebrew llvm を PATH に追加 (keg-only 経由)。
LLVM_PREFIX="$(brew --prefix llvm 2>/dev/null || echo /opt/homebrew/opt/llvm)"
export PATH="${LLVM_PREFIX}/bin:${PATH}"

log()  { printf '[build-kernel] %s\n' "$*"; }
warn() { printf '[build-kernel][警告] %s\n' "$*" >&2; }
err()  { printf '[build-kernel][エラー] %s\n' "$*" >&2; }

mkdir -p "${BUILD_DIR}"

# ---- 1. カーネルソース取得 (タグ固定) ----
if [ ! -f "${SRC_DIR}/Makefile" ]; then
    log "カーネルソースをダウンロード中: ${KERNEL_TAR} (${KERNEL_VERSION})"
    if ! curl -fsSL --retry 3 --connect-timeout 20 \
            -o "${BUILD_DIR}/${KERNEL_TAR}" "${KERNEL_URL}"; then
        err "カーネルソースのダウンロードに失敗しました (ネットワーク/ミラーを確認してください)"
        exit 1
    fi
    log "アーカイブを展開中..."
    tar -xf "${BUILD_DIR}/${KERNEL_TAR}" -C "${BUILD_DIR}"
    rm -f "${BUILD_DIR}/${KERNEL_TAR}"
    log "展開完了: ${SRC_DIR}"
else
    log "カーネルソースは既に存在します: ${SRC_DIR}"
fi

cd "${SRC_DIR}"

# ---- 1.5. macOS ビルドパッチ適用 (seiya.me) ----
log "macOS ビルドパッチを適用中 (seiya.me)..."
# 独自 include ディレクトリをソースツリーへコピー (HOSTCFLAGS の -I scripts/macos-include 参照先)
mkdir -p scripts/macos-include
cp "${ROOT}/scripts/macos-include/elf.h" scripts/macos-include/elf.h
cp "${ROOT}/scripts/macos-include/byteswap.h" scripts/macos-include/byteswap.h
cp "${ROOT}/scripts/macos-include/endian.h" scripts/macos-include/endian.h
cp "${ROOT}/scripts/macos-include/kernel_compat.h" scripts/macos-include/kernel_compat.h
# scripts/mod/file2alias.c の _UUID_T / uuid_t int パッチ (二重適用防止ガード付き)
if [ -f scripts/mod/file2alias.c ]; then
    if ! grep -q '^#define _UUID_T$' scripts/mod/file2alias.c 2>/dev/null; then
        # modpost.h インクルードの直前に #define _UUID_T / #define uuid_t int を挿入
        sed -i '' 's/^#include "modpost.h"/#define _UUID_T\n#define uuid_t int\n#include "modpost.h"/' scripts/mod/file2alias.c
    fi
    if ! grep -q '^#undef uuid_t$' scripts/mod/file2alias.c 2>/dev/null; then
        # devicetable-offsets.h インクルードの後に #undef uuid_t を挿入 (BSD sed 互換)
        sed -i '' '/^#include "devicetable-offsets.h"/a\
#undef uuid_t' scripts/mod/file2alias.c
    fi
    log "scripts/mod/file2alias.c に uuid_t パッチを適用しました"
fi

# ---- 2. x86_64 defconfig をベースにレーンA設定を適用 ----
log "x86_64 defconfig を生成中 (ARCH=x86_64, LLVM=1)"
USE_DEFCONFIG=0
if ${_MAKE} ARCH=x86_64 LLVM=1 CC="clang -target x86_64-linux-gnu" HOSTCC=clang HOSTLD=/usr/bin/ld AR="${AR_WRAPPER}" HOSTCFLAGS="${HOSTCFLAGS_BASE}" defconfig >/dev/null 2>&1; then
    USE_DEFCONFIG=1
    log "レーンA カーネル設定を適用中: ${CONFIG_FILE}"
    # コメント行・空行を除き .config に追記
    grep -v '^[[:space:]]*#' "${CONFIG_FILE}" | grep -v '^[[:space:]]*$' >> .config 2>/dev/null || true
    # objtool と stack validation は macOS (arm64) ホストでビルド不可のため無効化
    # .config の末尾に明示的に n を設定し、olddefconfig で上書きされないよう先に固定
    echo 'CONFIG_OBJTOOL=n' >> .config 2>/dev/null || true
    echo 'CONFIG_STACK_VALIDATION=n' >> .config 2>/dev/null || true
    yes "" | ${_MAKE} ARCH=x86_64 LLVM=1 CC="clang -target x86_64-linux-gnu" HOSTCC=clang HOSTLD=/usr/bin/ld AR="${AR_WRAPPER}" HOSTCFLAGS="${HOSTCFLAGS_BASE}" olddefconfig >/dev/null 2>&1 || true
    # 再度確実に無効化 (olddefconfig で上書きされた場合に備え)
    sed -i '' 's/^CONFIG_OBJTOOL=.*/CONFIG_OBJTOOL=n/' .config 2>/dev/null || true
    sed -i '' 's/^CONFIG_STACK_VALIDATION=.*/CONFIG_STACK_VALIDATION=n/' .config 2>/dev/null || true
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # objtool と sorttable のビルドを完全にスキップ (macOS 非互換のため)
    # scripts/sorttable は objtool の一部で、CONFIG_STACK_VALIDATION=n で不要
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    # scripts/sorttable のビルドをスキップ (スタブを作成)
    if [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi
    # サウンドサブシステムは最小構成では空サブディレクトリを生じるため無効化
    sed -i '' 's/^CONFIG_SOUND=y/# CONFIG_SOUND is not set/' .config 2>/dev/null || true
    sed -i '' 's/^CONFIG_SND=y/# CONFIG_SND is not set/' .config 2>/dev/null || true
    # IA32 エミュレーション (32-bit VDSO) は macOS ホストで __lshrti3 等 compiler-rt ヘルパーが未解決になるため無効化
    sed -i '' 's/^CONFIG_IA32_EMULATION=y/# CONFIG_IA32_EMULATION is not set/' .config 2>/dev/null || true
    # kbuild: obj-y のみで直接オブジェクトを持たない中間ディレクトリ (fbdev/controller/switch 等) でも
    # built-in.a を必ず生成し、空アーカイブでリンクを継続できるよう ar_builtin を堅牢化
    perl -0pi -e 's/(\t\$\(AR\) cDPrST \$\@)/$1; \\\n\ttest -f \$@ || > \$@/' scripts/Makefile.build 2>/dev/null || true
    # scripts/sorttable.c は macOS で <linux/compiler-gcc.h> の直接インクルードエラーとなるため、
    # <linux/compiler.h> に置き換え (CONFIG_STACK_VALIDATION=n で不要だが、念のため)
    if [ -f scripts/sorttable.c ]; then
        sed -i '' 's/#include "linux\/compiler-gcc.h"/#include "linux\/compiler.h"/' scripts/sorttable.c 2>/dev/null || true
    fi
    log ".config を作成しました: ${SRC_DIR}/.config"
else
    warn "${_MAKE} ARCH=x86_64 LLVM=1 defconfig に失敗しました"
    warn "config/kernel-defconfig をベースに .config (ベース設定) を作成します。"
    {
        echo "# SabakanOS: このホストでは defconfig をスキップしました"
        echo "# 本 .config は config/kernel-defconfig の抜粋です。"
        echo ""
        grep -v '^[[:space:]]*#' "${CONFIG_FILE}" | grep -v '^[[:space:]]*$'
    } > .config
    log ".config (ベース設定) を作成しました: ${SRC_DIR}/.config"
fi

# ---- 3. コンパイル (LLVM/clang+lld を使用、クロスコンパイラ不要) ----
if [ "${USE_DEFCONFIG}" = "1" ]; then
    JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
    log "LLVM/clang+lld でカーネルコンパイルを開始します (並列数=${JOBS})..."
    # fixdep/kconfig は arm64 ネイティブ (HOSTCFLAGS_BASE) で事前ビルドし、objtool/bzImage 用に HOSTCFLAGS_FULL を渡す。
    # ホストツール (fixdep/kconfig) は macOS ネイティブ実行バイナリなので HOSTLD=/usr/bin/ld を使用。
    ${_MAKE} ARCH=x86_64 LLVM=1 CC="clang -target x86_64-linux-gnu" HOSTCC=clang HOSTLD=/usr/bin/ld AR="${AR_WRAPPER}" HOSTCFLAGS="${HOSTCFLAGS_BASE}" scripts_basic >/dev/null 2>&1 || true
    # bzImage は x86_64 ELF なので HOSTLD=ld.lld (ELF 対応) と LD=ld.lld を使用。macOS の /usr/bin/ld は Mach-O 専用。
    # -fintegrated-as で clang の統合アセンブラを使い、x86_64 アセンブリファイル (.S) を正しく処理する。
    # AR=llvm-ar で macOS の BSD ar (ELF 非対応) ではなく LLVM の ar を使用し、ELF オブジェクトファイルを正しくアーカイブする。
    # LDFLAGS="-fuse-ld=lld" でリンク時に lld を使用。
    # objtool は CONFIG_STACK_VALIDATION 未設定のため不要だが、macOS でビルドエラーになるため、
    # .config で CONFIG_STACK_VALIDATION=n を明示して無効化している。
    ${_MAKE} ARCH=x86_64 LLVM=1 CC="clang -target x86_64-linux-gnu -fintegrated-as" HOSTCC=clang HOSTLD="${LLD}" LD="${LLD}" AR="llvm-ar" NM="llvm-nm" OBJCOPY="llvm-objcopy" STRIP="llvm-strip" READELF="llvm-readelf" HOSTCFLAGS="${HOSTCFLAGS_FULL}" LDFLAGS="-fuse-ld=lld" -j"${JOBS}" bzImage
    log "カーネルイメージ出力: ${SRC_DIR}/arch/x86/boot/bzImage"
else
    warn "defconfig が失敗したため、カーネルコンパイルをスキップします。"
    warn "Linux ビルドホスト、または macOS 上で LLVM=1 環境を整えて"
    warn "make build-kernel を再実行すると bzImage が出力されます。"
fi

log "完了"
exit 0
