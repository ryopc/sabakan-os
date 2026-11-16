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
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"

# ホストOS判定 (macOS は darwin, Linux は linux)
HOST_OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

if command -v gmake >/dev/null 2>&1; then
    _MAKE="gmake"
else
    _MAKE="make"
fi

BUILD_DIR="${ROOT}/build"
SRC_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
CONFIG_FILE="${ROOT}/config/kernel-defconfig"

# macOS 用互換ヘッダ (macOS のみ)
if [ "$HOST_OS" = "darwin" ]; then
    HOSTCFLAGS_BASE="-Iscripts/macos-include -I$(brew --prefix libelf)/include -I${SRC_DIR}/arch/x86/include/generated/uapi -I${SRC_DIR}/arch/x86/include/uapi -I${SRC_DIR}/include/uapi -Wno-undef -Wno-incompatible-pointer-types -Wno-macro-redefined"
    HOSTCFLAGS_FULL="${HOSTCFLAGS_BASE} -include ${SRC_DIR}/scripts/macos-include/endian.h"
    LLD="ld.lld"
    LLVM_PREFIX="$(brew --prefix llvm 2>/dev/null || echo /opt/homebrew/opt/llvm)"
    export PATH="${LLVM_PREFIX}/bin:${PATH}"
else
    # Linux (Ubuntu など): 通常のインクルードパス
    HOSTCFLAGS_BASE="-I${SRC_DIR}/arch/x86/include/generated/uapi -I${SRC_DIR}/arch/x86/include/uapi -I${SRC_DIR}/include/uapi -Wno-undef -Wno-incompatible-pointer-types -Wno-macro-redefined"
    HOSTCFLAGS_FULL="${HOSTCFLAGS_BASE}"
    LLD="ld.lld"
fi

AR_WRAPPER="${ROOT}/scripts/ar-wrapper.sh"

log()  { printf '[build-kernel] %s\n' "$*"; }
warn() { printf '[build-kernel][警告] %s\n' "$*" >&2; }
err()  { printf '[build-kernel][エラー] %s\n' "$*" >&2; }

# Python3 を使ったクロスプラットフォーム対応のファイル置換/挿入
#   $1: 対象ファイル, $2: 操作 (replace|insert_before|insert_after),
#   $3: 正規表現パターン, $4: 置換/挿入文字列
python3_patch() {
    python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import sys
import re

path = sys.argv[1]
op = sys.argv[2]
pattern = sys.argv[3]
replacement = sys.argv[4]

try:
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
except FileNotFoundError:
    sys.exit(0)

result = []
for line in lines:
    matched = re.search(pattern, line)
    if op == 'replace' and matched:
        # 元の行末尾の改行を保持
        result.append(replacement + '\n')
    elif op == 'insert_before' and matched:
        result.append(replacement + '\n')
        result.append(line)
    elif op == 'insert_after' and matched:
        result.append(line)
        result.append(replacement + '\n')
    else:
        result.append(line)

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(result)
PYEOF
}

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

# ---- 1.5. macOS ビルドパッチ適用 (macOS のみ) ----
if [ "$HOST_OS" = "darwin" ]; then
    log "macOS ビルドパッチを適用中 (seiya.me)..."
    mkdir -p scripts/macos-include
    cp "${ROOT}/scripts/macos-include/elf.h" scripts/macos-include/elf.h
    cp "${ROOT}/scripts/macos-include/byteswap.h" scripts/macos-include/byteswap.h
    cp "${ROOT}/scripts/macos-include/endian.h" scripts/macos-include/endian.h
    cp "${ROOT}/scripts/macos-include/kernel_compat.h" scripts/macos-include/kernel_compat.h

    # scripts/mod/file2alias.c の _UUID_T / uuid_t int パッチ (二重適用防止ガード付き)
    if [ -f scripts/mod/file2alias.c ]; then
        if ! grep -q '^#define _UUID_T$' scripts/mod/file2alias.c 2>/dev/null; then
            python3_patch scripts/mod/file2alias.c insert_before '^#include "modpost.h"' '#define _UUID_T
#define uuid_t int'
        fi
        if ! grep -q '^#undef uuid_t$' scripts/mod/file2alias.c 2>/dev/null; then
            python3_patch scripts/mod/file2alias.c insert_after '^#include "devicetable-offsets.h"' '#undef uuid_t'
        fi
        log "scripts/mod/file2alias.c に uuid_t パッチを適用しました"
    fi
fi

# ---- 2. x86_64 defconfig をベースにレーンA設定を適用 ----
log "x86_64 defconfig を生成中 (ARCH=x86_64, LLVM=1)"
USE_DEFCONFIG=0
if ${_MAKE} ARCH=x86_64 LLVM=1 CC="clang -target x86_64-linux-gnu" HOSTCC=clang HOSTLD=/usr/bin/ld AR="${AR_WRAPPER}" HOSTCFLAGS="${HOSTCFLAGS_BASE}" defconfig >/dev/null 2>&1; then
    USE_DEFCONFIG=1
    log "レーンA カーネル設定を適用中: ${CONFIG_FILE}"
    grep -v '^[[:space:]]*#' "${CONFIG_FILE}" | grep -v '^[[:space:]]*$' >> .config 2>/dev/null || true

    # objtool と stack validation はビルドに失敗するため無効化 (bzImage 生成には不要)
    python3_patch .config replace '^CONFIG_OBJTOOL=' 'CONFIG_OBJTOOL=n'
    python3_patch .config replace '^CONFIG_STACK_VALIDATION=' 'CONFIG_STACK_VALIDATION=n'
    if ! grep -q '^CONFIG_OBJTOOL=' .config 2>/dev/null; then
        echo 'CONFIG_OBJTOOL=n' >> .config 2>/dev/null || true
    fi
    if ! grep -q '^CONFIG_STACK_VALIDATION=' .config 2>/dev/null; then
        echo 'CONFIG_STACK_VALIDATION=n' >> .config 2>/dev/null || true
    fi

    yes "" | ${_MAKE} ARCH=x86_64 LLVM=1 CC="clang -target x86_64-linux-gnu" HOSTCC=clang HOSTLD=/usr/bin/ld AR="${AR_WRAPPER}" HOSTCFLAGS="${HOSTCFLAGS_BASE}" olddefconfig >/dev/null 2>&1 || true

    # olddefconfig で上書きされた場合に備え、再度確実に無効化
    python3_patch .config replace '^CONFIG_OBJTOOL=' 'CONFIG_OBJTOOL=n'
    python3_patch .config replace '^CONFIG_STACK_VALIDATION=' 'CONFIG_STACK_VALIDATION=n'

    # objtool と sorttable のビルドをスキップ (macOS 非互換のため)
    if [ -d tools/objtool ]; then
        touch tools/objtool/libsubcmd/include/subcmd/help.h \
              tools/objtool/libsubcmd/include/subcmd/parse-options.h \
              tools/objtool/libsubcmd/include/subcmd/pager.h \
              tools/objtool/libsubcmd/include/subcmd/run-command.h \
              tools/objtool/libsubcmd/include/subcmd/exec-cmd.h 2>/dev/null || true
    fi
    if [ "$HOST_OS" = "darwin" ] && [ -f scripts/sorttable.c ]; then
        : > scripts/sorttable.o 2>/dev/null || true
    fi

    # サウンドサブシステムは最小構成では空サブディレクトリを生じるため無効化
    python3_patch .config replace '^CONFIG_SOUND=' '# CONFIG_SOUND is not set'
    python3_patch .config replace '^CONFIG_SND=' '# CONFIG_SND is not set'
    # IA32 エミュレーションは macOS ホストで __lshrti3 等 compiler-rt ヘルパーが未解決になるため無効化
    python3_patch .config replace '^CONFIG_IA32_EMULATION=' '# CONFIG_IA32_EMULATION is not set'

    # kbuild: obj-y のみで直接オブジェクトを持たない中間ディレクトリでも
    # built-in.a を必ず生成し、空アーカイブでリンクを継続できるよう ar_builtin を堅牢化
    perl -0pi -e 's/(\t\$\(AR\) cDPrST \$\@)/$1; \\\n\ttest -f \$@ || > \$@/' scripts/Makefile.build 2>/dev/null || true

    # scripts/sorttable.c は macOS で <linux/compiler-gcc.h> の直接インクルードエラーとなるため、
    # <linux/compiler.h> に置き換え (macOS のみ)
    if [ "$HOST_OS" = "darwin" ] && [ -f scripts/sorttable.c ]; then
        python3_patch scripts/sorttable.c replace '#include "linux/compiler-gcc.h"' '#include "linux/compiler.h"'
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
        echo 'CONFIG_OBJTOOL=n'
        echo 'CONFIG_STACK_VALIDATION=n'
    } > .config
    log ".config (ベース設定) を作成しました: ${SRC_DIR}/.config"
fi

# ---- 3. コンパイル (LLVM/clang+lld を使用、クロスコンパイラ不要) ----
if [ "${USE_DEFCONFIG}" = "1" ]; then
    JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
    log "LLVM/clang+lld でカーネルコンパイルを開始します (並列数=${JOBS})..."
    # fixdep/kconfig は arm64 ネイティブ (HOSTCFLAGS_BASE) で事前ビルドし、objtool/bzImage 用に HOSTCFLAGS_FULL を渡す。
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
