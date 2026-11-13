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
log "x86_64 defconfig を生成中 (ARCH=x86_64)"
USE_DEFCONFIG=0
if ${_MAKE} ARCH=x86_64 defconfig >/dev/null 2>&1; then
    USE_DEFCONFIG=1
    log "レーンA カーネル設定を適用中: ${CONFIG_FILE}"
    # コメント行・空行を除き .config に追記 (olddefconfig で整合性・補完)
    grep -v '^[[:space:]]*#' "${CONFIG_FILE}" | grep -v '^[[:space:]]*$' >> .config 2>/dev/null || true
    ${_MAKE} ARCH=x86_64 olddefconfig >/dev/null 2>&1 || true
    log ".config を作成しました: ${SRC_DIR}/.config"
else
    warn "${_MAKE} ARCH=x86_64 defconfig に失敗しました (ホストツールチェインの制約: macOS/Apple ld 等)"
    warn "config/kernel-defconfig をベースに .config (ベース設定) を作成します。"
    warn "Linux ビルドホストで 'make ARCH=x86_64 olddefconfig' を実行して完全な設定を補完してください。"
    {
        echo "# SabakanOS: このホストでは defconfig をスキップしました (ツールチェイン制約)"
        echo "# 本 .config は config/kernel-defconfig の抜粋です。Linux ビルドホストで"
        echo "# 'make ARCH=x86_64 olddefconfig' を実行して完全な設定を補完してください。"
        echo ""
        grep -v '^[[:space:]]*#' "${CONFIG_FILE}" | grep -v '^[[:space:]]*$'
    } > .config
    log ".config (ベース設定) を作成しました: ${SRC_DIR}/.config"
fi

# ---- 3. コンパイル (クロスコンパイラがある場合のみ) ----
CROSS=""
for cc in x86_64-linux-musl-gcc x86_64-linux-gnu-gcc x86_64-elf-gcc; do
    if command -v "${cc}" >/dev/null 2>&1; then
        # x86_64-linux-musl-gcc -> x86_64-linux-musl-
        CROSS="${cc%-gcc}-"
        break
    fi
done

if [ -n "${CROSS}" ] && [ "${USE_DEFCONFIG}" = "1" ]; then
    JOBS="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"
    log "クロスコンパイラ検出: ${CROSS}gcc  (並列数=${JOBS})"
    log "カーネルコンパイルを開始します..."
    ${_MAKE} ARCH=x86_64 CROSS_COMPILE="${CROSS}" -j"${JOBS}" bzImage
    log "カーネルイメージ出力: ${SRC_DIR}/arch/x86/boot/bzImage"
else
    warn "x86_64 Linux 向けクロスコンパイラが見つかりません (x86_64-linux-musl-gcc 等)"
    warn "実際のコンパイルをスキップし、.config のみを生成しました。"
    warn "Linux ビルドホスト、または Buildroot ツールチェインを導入した環境で"
    warn "make build-kernel を再実行すると bzImage が出力されます。"
fi

log "完了"
exit 0
