#!/bin/sh
#
# scripts/build-kernel.sh — SabakanOS レーンA: Linux カーネルビルド (Linux ネイティブ版)
#
# 対象: Ubuntu 24.04 (GitHub Actions ubuntu-24.04) など、ホストが x86_64 Linux の環境
#
# 前提パッケージ:
#   sudo apt-get install -y build-essential flex bison libelf-dev libssl-dev bc dwarves
#
# 出力:
#   build/linux-<VERSION>/arch/x86/boot/bzImage
#
# 方針:
#   - set -eu により、途中の失敗は必ず終了コードに反映させる
#   - .config の変更は scripts/config と merge_config.sh で行う (sed による書き換えはしない)
#   - 成果物の存在を最後に確認し、無ければ失敗とする

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

KERNEL_VERSION="6.12.34"
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"

BUILD_DIR="${ROOT}/build"
SRC_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
CONFIG_FRAGMENT="${ROOT}/config/kernel-defconfig"
BZIMAGE="${SRC_DIR}/arch/x86/boot/bzImage"

JOBS="$(nproc 2>/dev/null || echo 2)"

log() { printf '[build-kernel] %s\n' "$*"; }
err() { printf '[build-kernel][エラー] %s\n' "$*" >&2; }

# ---- 0. 前提確認 ----
if [ "$(uname -s)" != "Linux" ]; then
    err "このスクリプトは Linux 専用です (macOS では動作しません)"
    exit 1
fi
if [ ! -f "${CONFIG_FRAGMENT}" ]; then
    err "設定フラグメントが見つかりません: ${CONFIG_FRAGMENT}"
    exit 1
fi

mkdir -p "${BUILD_DIR}"

# ---- 1. カーネルソース取得 (タグ固定) ----
if [ ! -f "${SRC_DIR}/Makefile" ]; then
    log "カーネルソースをダウンロード中: ${KERNEL_TAR}"
    curl -fsSL --retry 3 --connect-timeout 20 -o "${BUILD_DIR}/${KERNEL_TAR}" "${KERNEL_URL}"
    log "アーカイブを展開中..."
    tar -xf "${BUILD_DIR}/${KERNEL_TAR}" -C "${BUILD_DIR}"
    rm -f "${BUILD_DIR}/${KERNEL_TAR}"
else
    log "カーネルソースは既に存在します: ${SRC_DIR}"
fi

cd "${SRC_DIR}"

# ---- 2. 基準 defconfig + レーンA フラグメントを統合 ----
log "x86_64 defconfig を生成中"
make ARCH=x86_64 defconfig

log "レーンA フラグメントを統合中: ${CONFIG_FRAGMENT}"
scripts/kconfig/merge_config.sh -m -O . .config "${CONFIG_FRAGMENT}"

# ---- 3. objtool を無効化 ----
# x86_64 の既定 unwinder (ORC) は objtool を必要とするため、フレームポインタ方式へ切り替える。
# 注意: これは既定の unwinder を変更する判断です。不要であれば次の2行を削除してください。
scripts/config --disable UNWINDER_ORC --enable UNWINDER_FRAME_POINTER
scripts/config --disable OBJTOOL

make ARCH=x86_64 olddefconfig

# ---- 4. 設定値の検証 (意図どおりに反映されたか確認) ----
verify() {
    if ! grep -q "^$1\$" .config; then
        err "設定の検証に失敗しました: $1 が .config にありません"
        exit 1
    fi
}
verify "# CONFIG_OBJTOOL is not set"
verify "CONFIG_UNWINDER_FRAME_POINTER=y"
log "設定の検証に成功しました"

# ---- 5. コンパイル ----
log "カーネルをコンパイルします (並列数=${JOBS})"
make ARCH=x86_64 -j"${JOBS}" bzImage

# ---- 6. 成果物の確認 ----
if [ ! -f "${BZIMAGE}" ]; then
    err "bzImage が生成されませんでした: ${BZIMAGE}"
    exit 1
fi

log "カーネルイメージ出力: ${BZIMAGE}"
log "完了"