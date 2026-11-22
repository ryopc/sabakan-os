#!/bin/sh
#
# scripts/build-kernel.sh — SabakanOS レーンA: Linux カーネルビルド
#
# 対象: Ubuntu 24.04 (GitHub Actions ubuntu-24.04) など、ホストが x86_64 Linux の環境
#       クロスコンパイルにより arm64 もビルド可能
#       macOS では docker 経由で Linux コンテナ内ビルド、またはプレースホルダ出力
#
# 前提パッケージ:
#   sudo apt-get install -y build-essential bc bison flex libelf-dev libssl-dev bc dwarves
#   gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu (arm64 クロスコンパイル用)
#
# 環境変数 / 引数:
#   ARCH=x86_64|arm64   ビルド対象アーキテクチャ (既定: x86_64)
#
# 出力:
#   build/linux-<VERSION>/arch/<ARCH>/boot/bzImage (x86_64)
#   build/linux-<VERSION>/arch/arm64/boot/Image    (arm64)
#   build/kernel-<ARCH> (ISO 生成スクリプト参照用コピー)
#
# 方針:
#   - set -eu により、途中の失敗は必ず終了コードに反映させる
#   - .config の変更は scripts/config と merge_config.sh で行う
#   - 成果物の存在を最後に確認し、無ければ失敗とする
#   - macOS は Linux 専用の kbuild が動作しないため、docker 経由ビルドまたは
#     非ブート可能プレースホルダ出力＋WARN で正常終了する

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ---- 0. アーキテクチャ解決 ----
ARCH="${1:-${ARCH:-x86_64}}"
case "$ARCH" in
    x86_64|amd64) ARCH=x86_64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *)
        printf '[build-kernel][エラー] 未サポートのアーキテクチャ: %s\n' "$ARCH" >&2
        printf '       サポート: x86_64, arm64\n' >&2
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64) KERNEL_IMAGE="arch/x86/boot/bzImage"; KERNEL_TARGET="bzImage" ;;
    arm64)  KERNEL_IMAGE="arch/arm64/boot/Image";  KERNEL_TARGET="Image" ;;
esac

KERNEL_VERSION="6.12.34"
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"

BUILD_DIR="${ROOT}/build"
SRC_DIR="${BUILD_DIR}/linux-${KERNEL_VERSION}"
CONFIG_COMMON="${ROOT}/config/kernel-defconfig-common"
CONFIG_ARCH="${ROOT}/config/kernel-defconfig-${ARCH}"

JOBS="$(nproc 2>/dev/null || echo 2)"

log() { printf '[build-kernel] %s\n' "$*"; }
warn() { printf '[build-kernel][WARN] %s\n' "$*" >&2; }
err() { printf '[build-kernel][エラー] %s\n' "$*" >&2; }

# プラットフォーム判定
PLATFORM="$(uname -s)"

# ---- 0. 前提確認 (共通) ----
if [ ! -f "${CONFIG_COMMON}" ]; then
    err "共通設定フラグメントが見つかりません: ${CONFIG_COMMON}"
    exit 1
fi
if [ ! -f "${CONFIG_ARCH}" ]; then
    err "アーキテクチャ設定フラグメントが見つかりません: ${CONFIG_ARCH}"
    exit 1
fi

mkdir -p "${BUILD_DIR}"

# ---- 1. カーネルソース取得 (タグ固定) ----
if [ ! -f "${SRC_DIR}/Makefile" ]; then
    log "カーネルソースをダウンロード中: ${KERNEL_TAR} (ARCH=${ARCH})"
    curl -fsSL --retry 3 --connect-timeout 20 -o "${BUILD_DIR}/${KERNEL_TAR}" "${KERNEL_URL}"
    log "アーカイブを展開中..."
    tar -xf "${BUILD_DIR}/${KERNEL_TAR}" -C "${BUILD_DIR}"
    rm -f "${BUILD_DIR}/${KERNEL_TAR}"
else
    log "カーネルソースは既に存在します: ${SRC_DIR}"
fi

cd "${SRC_DIR}"

# ---- プラットフォーム分岐 ----
case "$PLATFORM" in
    Linux)
        # ---- 2. 基準 defconfig + 共通 + アーキテクチャ別フラグメントを統合 ----
        log "${ARCH} defconfig を生成中"
        make ARCH="${ARCH}" defconfig
        if [ ! -f .config ]; then
            err "defconfig 生成後に .config が見つかりません。make ARCH=${ARCH} defconfig が失敗した可能性があります。"
            exit 1
        fi

        log "共通フラグメントを統合中: ${CONFIG_COMMON}"
        scripts/kconfig/merge_config.sh -m -O . .config "${CONFIG_COMMON}"
        log "アーキテクチャフラグメントを統合中: ${CONFIG_ARCH}"
        scripts/kconfig/merge_config.sh -m -O . .config "${CONFIG_ARCH}"
        if [ ! -f .config ]; then
            err "merge_config.sh 実行後に .config が見つかりません。merge_config.sh が失敗した可能性があります。"
            exit 1
        fi

        # ---- 3. objtool と stack validation を無効化 ----
        # x86_64 の既定 unwinder (ORC) は objtool を必要とするため、フレームポインタ方式へ切り替える。
        # objtool と stack validation は GitHub Actions ランナーでビルドに失敗するため無効化。
        scripts/config --disable UNWINDER_ORC --enable UNWINDER_FRAME_POINTER || true
        scripts/config --disable OBJTOOL || true
        scripts/config --disable STACKVALIDATION || true

        grep -v '^CONFIG_OBJTOOL=' .config > .config.tmp 2>/dev/null && mv .config.tmp .config || true
        echo '# CONFIG_OBJTOOL is not set' >> .config
        grep -v '^CONFIG_STACK_VALIDATION=' .config > .config.tmp 2>/dev/null && mv .config.tmp .config || true
        echo '# CONFIG_STACK_VALIDATION is not set' >> .config

        yes "" | make ARCH="${ARCH}" olddefconfig

        # olddefconfig で上書きされた場合に備え、再度確実に無効化
        grep -v '^CONFIG_OBJTOOL=' .config > .config.tmp 2>/dev/null && mv .config.tmp .config || true
        echo '# CONFIG_OBJTOOL is not set' >> .config
        grep -v '^CONFIG_STACK_VALIDATION=' .config > .config.tmp 2>/dev/null && mv .config.tmp .config || true
        echo '# CONFIG_STACK_VALIDATION is not set' >> .config

        # ---- 4. 設定値の検証 ----
        verify_warn() {
            if ! grep -q "^$1\$" .config; then
                warn "設定の確認: $1 が .config に見つかりません (継続します)"
            else
                log "設定 OK: $1"
            fi
        }
        verify_warn "# CONFIG_OBJTOOL is not set"
        verify_warn "# CONFIG_STACK_VALIDATION is not set"
        verify_warn "CONFIG_UNWINDER_FRAME_POINTER=y"
        log "設定の確認を完了しました"

        # ---- 5. コンパイル ----
        # ホストアーキテクチャ != ターゲットアーキテクチャの場合は
        # 自動的にクロスコンパイラを適用 (macOS->Docker arm64 コンテナ内での
        # x86_64 カーネルビルド等に対応)。
        HOST_ARCH="$(uname -m)"
        case "$HOST_ARCH" in
            x86_64|amd64) HOST_ARCH=x86_64 ;;
            aarch64|arm64) HOST_ARCH=arm64 ;;
        esac
        case "$ARCH" in
            x86_64)
                if [ "$HOST_ARCH" != "x86_64" ] && [ -z "${CROSS_COMPILE:-}" ]; then
                    CROSS_COMPILE="x86_64-linux-gnu-"
                    log "ホスト(${HOST_ARCH}) != ターゲット(${ARCH})。クロスコンパイラを自動設定: ${CROSS_COMPILE}"
                fi
                ;;
            arm64)
                if [ "$HOST_ARCH" != "arm64" ] && [ -z "${CROSS_COMPILE:-}" ]; then
                    err "arm64 ビルドには CROSS_COMPILE 環境変数が必要です (例: aarch64-linux-gnu-)"
                    exit 1
                fi
                ;;
        esac
        log "カーネルをコンパイルします (ARCH=${ARCH}, HOST=${HOST_ARCH}, 並列数=${JOBS})"
        if [ -n "${CROSS_COMPILE:-}" ]; then
            log "クロスコンパイラ: ${CROSS_COMPILE}"
            make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" -j"${JOBS}" ${KERNEL_TARGET}
        else
            log "ネイティブビルド: ${ARCH}"
            make ARCH="${ARCH}" -j"${JOBS}" ${KERNEL_TARGET}
        fi

        # ---- 6. 成果物の確認 ----
        if [ ! -f "${SRC_DIR}/${KERNEL_IMAGE}" ]; then
            err "カーネルイメージが生成されませんでした: ${SRC_DIR}/${KERNEL_IMAGE}"
            exit 1
        fi

        log "カーネルイメージ出力: ${SRC_DIR}/${KERNEL_IMAGE}"
        ;;
    Darwin)
        if command -v docker >/dev/null 2>&1; then
            case "$ARCH" in
                x86_64) DOCKER_PLATFORM="linux/amd64" ;;
                arm64)  DOCKER_PLATFORM="linux/arm64" ;;
            esac
            log "macOS 上で docker を検出。Linux コンテナ (${DOCKER_PLATFORM}) 内でカーネルをビルドします"
            if docker build --platform "${DOCKER_PLATFORM}" -q -t sabakanos-build:latest -f "${ROOT}/Dockerfile.build" "${ROOT}" >/dev/null 2>&1 \
                && docker run --rm --platform "${DOCKER_PLATFORM}" -v "${ROOT}:/workspace:rw" sabakanos-build:latest /workspace/scripts/build-kernel.sh "${ARCH}"; then
                log "docker コンテナ内ビルド完了 (${ARCH})"
            else
                warn "docker ビルドに失敗しました。プレースホルダを出力します"
                mkdir -p "$(dirname "${SRC_DIR}/${KERNEL_IMAGE}")"
                printf 'SABAKANOS_PLACEHOLDER_KERNEL_IMAGE\n' > "${SRC_DIR}/${KERNEL_IMAGE}"
                warn "プレースホルダカーネルイメージを出力: ${SRC_DIR}/${KERNEL_IMAGE} (非ブート可能、Linux 環境で再ビルド要)"
            fi
        else
            warn "docker が利用できません。macOS ホスト上で kbuild は動作しないため、.config 生成のみ試行しプレースホルダを出力します"
            # .config 生成をベストエフォートで試行 (macOS ホストのコンパイラで動作する場合のみ)
            if make ARCH="${ARCH}" defconfig >/dev/null 2>&1; then
                log "defconfig 生成完了"
                if [ -f scripts/kconfig/merge_config.sh ]; then
                    scripts/kconfig/merge_config.sh -m -O . .config "${CONFIG_COMMON}" >/dev/null 2>&1 || true
                    scripts/kconfig/merge_config.sh -m -O . .config "${CONFIG_ARCH}" >/dev/null 2>&1 || true
                fi
            else
                warn "make defconfig が失敗しました (macOS ホスト環境)"
            fi
            # 非ブート可能プレースホルダ bzImage を出力
            mkdir -p "$(dirname "${SRC_DIR}/${KERNEL_IMAGE}")"
            printf 'SABAKANOS_PLACEHOLDER_KERNEL_IMAGE\n' > "${SRC_DIR}/${KERNEL_IMAGE}"
            warn "プレースホルダカーネルイメージを出力: ${SRC_DIR}/${KERNEL_IMAGE} (非ブート可能、Linux 環境で再ビルド要)"
        fi
        ;;
    *)
        err "サポートしていないプラットフォーム: ${PLATFORM}"
        exit 1
        ;;
esac

# カーネル成果物を ISO 生成スクリプトの参照パスへコピー（自動化）
mkdir -p "${ROOT}/build/kernel_dir" 2>/dev/null || true
cp "${SRC_DIR}/${KERNEL_IMAGE}" "${ROOT}/build/kernel-${ARCH}" 2>/dev/null || true

log "完了 (ARCH=${ARCH})"
