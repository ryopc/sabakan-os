#!/bin/bash
#
# scripts/run-qemu.sh — SabakanOS QEMU 起動スクリプト (レーンB 所有)
#
# 概要:
#   scripts/build-iso.sh で生成したブート可能 ISO を QEMU (x86_64) で起動する。
#   ISO が未生成の場合は build-iso.sh の実行を促して停止する。
#
# 使い方:
#   ./scripts/run-qemu.sh           # デフォルトオプションで起動
#   QEMU_OPTS="-m 4G" ./scripts/run-qemu.sh  # 環境変数でオプション上書き可能
#
# 参考: /Users/ryotagtagtag/projects/os/scripts/run-qemu.sh
#
# 注意:
#   本スクリプトは Makefile / config/ / rootfs/ など他レーン所有ファイルには
#   触れず、build/ 配下の ISO 成果物のみを参照する。

set -euo pipefail

# ---------------------------------------------------------------------------
# パス設定 (スクリプト位置からプロジェクトルートを解決)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ISO イメージのパス (build-iso.sh の出力と合わせる)
ISO="$PROJECT_ROOT/build/sabakanos.iso"

# 既定の QEMU オプション
#   -m 2G      : メモリ 2GB
#   -serial stdio : シリアルコンソールを標準入出力に接続 (カーネルログ確認用)
#   -vga std   : 標準 VGA
#   -cdrom     : ブートメディアとして ISO を指定
DEFAULT_QEMU_OPTS="-m 2G -serial stdio -vga std"
QEMU_OPTS="${QEMU_OPTS:-$DEFAULT_QEMU_OPTS}"

# ---------------------------------------------------------------------------
# ユーティリティ
# ---------------------------------------------------------------------------
log()  { printf '[run-qemu] %b\n' "$*"; }
die()  { printf '[run-qemu][ERROR] %b\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# QEMU 存在チェック
# ---------------------------------------------------------------------------
check_qemu() {
    if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
        die "qemu-system-x86_64 が見つかりません。\n"\
            "  macOS: brew install qemu\n"\
            "  Ubuntu/Debian: sudo apt-get install qemu-system-x86"
    fi
}

# ---------------------------------------------------------------------------
# ISO 存在チェック (未生成時は build-iso.sh を促して停止)
# ---------------------------------------------------------------------------
check_iso() {
    if [[ ! -f "$ISO" ]]; then
        die "ISO イメージが見つかりません: $ISO\n"\
            "  先に以下を実行して ISO を生成してください:\n"\
            "    ./scripts/build-iso.sh\n"\
            "  (必要に応じて依存ツールのインストールおよびカーネル/initramfs の配置が必要です)"
    fi
}

# ---------------------------------------------------------------------------
# メイン
# ---------------------------------------------------------------------------
main() {
    log "SabakanOS QEMU 起動スクリプト"
    log "プロジェクトルート: $PROJECT_ROOT"

    check_qemu
    check_iso

    log "ISO イメージ: $ISO"
    log "QEMU オプション: $QEMU_OPTS"
    log "起動中... (終了するには QEMU ウィンドウを閉じるか C-a c → quit)"

    # shellcheck disable=SC2086
    exec qemu-system-x86_64 $QEMU_OPTS -cdrom "$ISO"
}

main "$@"
