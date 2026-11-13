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

KERNEL_VERSION="6.18.63"
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
HOSTCFLAGS="-Iscripts/macos-include -I$(brew --prefix libelf)/include"

BUILD_DIR="${ROOT}/build"
SRC_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
CONFIG_FILE="${ROOT}/config/kernel-defconfig"

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

# ---- 2. x86_64 defconfig をベースにレーンA設定を適用 ----
log "x86_64 defconfig を生成中 (ARCH=x86_64, LLVM=1)"
USE_DEFCONFIG=0
if ${_MAKE} ARCH=x86_64 LLVM=1 HOSTCFLAGS="${HOSTCFLAGS}" defconfig >/dev/null 2>&1; then
    USE_DEFCONFIG=1
    log "レーンA カーネル設定を適用中: ${CONFIG_FILE}"
    # コメント行・空行を除き .config に追記 (olddefconfig で整合性・補完)
    grep -v '^[[:space:]]*#' "${CONFIG_FILE}" | grep -v '^[[:space:]]*$' >> .config 2>/dev/null || true
    yes "" | ${_MAKE} ARCH=x86_64 LLVM=1 HOSTCFLAGS="${HOSTCFLAGS}" olddefconfig >/dev/null 2>&1 || true
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
    ${_MAKE} ARCH=x86_64 LLVM=1 HOSTCFLAGS="${HOSTCFLAGS}" -j"${JOBS}" bzImage
    log "カーネルイメージ出力: ${SRC_DIR}/arch/x86/boot/bzImage"
else
    warn "defconfig が失敗したため、カーネルコンパイルをスキップします。"
    warn "Linux ビルドホスト、または macOS 上で LLVM=1 環境を整えて"
    warn "make build-kernel を再実行すると bzImage が出力されます。"
fi

log "完了"
exit 0
