#!/bin/bash
#
# scripts/run-qemu.sh — SabakanOS QEMU 起動スクリプト (レーンB 所有)
#
# 概要:
#   scripts/build-iso.sh で生成したブート可能 ISO を QEMU (x86_64) で起動する。
#   ISO が未生成の場合は build-iso.sh の実行を促して停止する。
#   シリアル出力をキャプチャし、「SabakanOS 起動完了」またはシェルプロンプト
#   を検出できなければ非ゼロ終了とする (ブート検証)。
#
# 使い方:
#   ./scripts/run-qemu.sh           # デフォルトオプションで起動
#   QEMU_OPTS="-m 4G" ./scripts/run-qemu.sh  # 環境変数でオプション上書き可能
#   QEMU_TIMEOUT=120 ./scripts/run-qemu.sh   # タイムアウト秒数 (既定 60)
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
#   -m 2G        : メモリ 2GB
#   -vga std     : 標準 VGA
#   -display none: ウィンドウを開かない (ヘッドレス)
# シリアル (ttyS0) は最初の -serial オプションとしてキャプチャファイルに接続し、
# カーネル cmdline (console=ttyS0) の出力を回収する。
DEFAULT_QEMU_OPTS="-m 2G -boot order=d -vga std -display none"
QEMU_OPTS="${QEMU_OPTS:-$DEFAULT_QEMU_OPTS}"
QEMU_TIMEOUT="${QEMU_TIMEOUT:-60}"

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
    log "タイムアウト: ${QEMU_TIMEOUT}秒"
    log "起動中..."

    # シリアル出力キャプチャ用一時ファイル (ttyS0 -> ここでキャプチャ)
    SERIAL_LOG="$(mktemp)"
    trap 'rm -f "$SERIAL_LOG"' EXIT

    # shellcheck disable=SC2086
    set +e
    timeout "${QEMU_TIMEOUT}" qemu-system-x86_64 -serial "file:${SERIAL_LOG}" $QEMU_OPTS -cdrom "$ISO" >/dev/null 2>&1
    qemu_status=$?
    set -e

    # キャプチャしたシリアル出力を標準出力にも反映
    if [ -f "$SERIAL_LOG" ]; then
        cat "$SERIAL_LOG"
    fi

    if [ "$qemu_status" -eq 124 ]; then
        die "QEMU 起動がタイムアウトしました (${QEMU_TIMEOUT}秒)"
    elif [ "$qemu_status" -ne 0 ]; then
        die "QEMU が異常終了しました (終了コード: $qemu_status)"
    fi

    # 起動成功の検出: シリアル出力から「SabakanOS 起動完了」またはシェルプロンプト
    if [ -f "$SERIAL_LOG" ] && grep -qE 'SabakanOS 起動完了|sabakan:.*#|sabakan login|root@sabakan' "$SERIAL_LOG"; then
        log "ブート成功: シリアル出力から起動完了/シェルプロンプトを検出"
        exit 0
    else
        die "ブート失敗: シリアル出力に起動完了/シェルプロンプトが検出されませんでした"
    fi
}

main "$@"
