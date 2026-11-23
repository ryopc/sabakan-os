#!/bin/bash
#
# scripts/run-qemu.sh — SabakanOS QEMU 起動スクリプト (レーンB 所有)
#
# 概要:
#   カーネルと initramfs を直接指定して QEMU (x86_64) で起動する。
#   ISO 経由の Limine BIOS ブートはシリアル出力が得られず CI でタイムアウトするため、
#   -kernel/-initrd で直接起動し、シリアル出力でブート検証を行う。
#
# 使い方:
#   ./scripts/run-qemu.sh           # デフォルトオプションで起動
#   QEMU_TIMEOUT=120 ./scripts/run-qemu.sh   # タイムアウト秒数 (既定 60)
#
# 参考: /Users/ryotagtagtag/projects/os/scripts/run-qemu.sh
#
# 注意:
#   本スクリプトは Makefile / config/ / rootfs/ など他レーン所有ファイルには
#   触れず、build/ 配下のカーネル/initramfs 成果物のみを参照する。

set -euo pipefail

# ---------------------------------------------------------------------------
# パス設定 (スクリプト位置からプロジェクトルートを解決)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# アーキテクチャ
ARCH="${ARCH:-x86_64}"
case "$ARCH" in
    x86_64|amd64) ARCH=x86_64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *)
        die "未サポートのアーキテクチャ: $ARCH (x86_64 または arm64 を指定してください)"
        ;;
esac

# 既定のタイムアウト
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
# カーネル・initramfs の解決
# ---------------------------------------------------------------------------
resolve_kernel_and_initramfs() {
    KERNEL_CANDIDATES=(
        "$PROJECT_ROOT/build/kernel"
        "$PROJECT_ROOT/build/kernel-${ARCH:-x86_64}"
        "$PROJECT_ROOT/build/linux-6.12.34/arch/x86/boot/bzImage"
        "$PROJECT_ROOT/build/kernel.elf"
        "$PROJECT_ROOT/build/bzImage"
        "$PROJECT_ROOT/rootfs/boot/kernel"
    )
    INITRAMFS_CANDIDATES=(
        "$PROJECT_ROOT/build/initramfs.img"
        "$PROJECT_ROOT/build/initrd.img"
        "$PROJECT_ROOT/build/initramfs"
        "$PROJECT_ROOT/rootfs/boot/initramfs.img"
        "$PROJECT_ROOT/rootfs/boot/initrd.img"
    )

    KERNEL=""
    for c in "${KERNEL_CANDIDATES[@]}"; do
        if [[ -f "$c" ]]; then
            KERNEL="$c"
            break
        fi
    done

    INITRAMFS=""
    for c in "${INITRAMFS_CANDIDATES[@]}"; do
        if [[ -f "$c" ]]; then
            INITRAMFS="$c"
            break
        fi
    done

    if [[ -z "$KERNEL" ]]; then
        die "カーネルイメージが見つかりません。\n"\
            "  先に 'make build-kernel' を実行して build/kernel を生成してください。\n"\
            "  候補: build/kernel, build/linux-6.12.34/arch/x86/boot/bzImage, rootfs/boot/kernel"
    fi
    if [[ -z "$INITRAMFS" ]]; then
        die "initramfs が見つかりません (必須)。\n"\
            "  先に 'make build-rootfs' (scripts/build-rootfs.sh) を実行して build/initramfs.img を生成してください。\n"\
            "  候補: build/initramfs.img, build/initrd.img, rootfs/boot/initramfs.img"
    fi

    log "カーネル: $KERNEL"
    log "initramfs: $INITRAMFS"
}

# ---------------------------------------------------------------------------
# メイン
# ---------------------------------------------------------------------------
main() {
    log "SabakanOS QEMU 起動スクリプト (カーネル直接ブート)"
    log "プロジェクトルート: $PROJECT_ROOT"

    check_qemu
    resolve_kernel_and_initramfs

    log "タイムアウト: ${QEMU_TIMEOUT}秒"
    log "起動中..."

    # シリアル出力キャプチャ用一時ファイル (ttyS0 -> ここでキャプチャ)
    SERIAL_LOG="$(mktemp)"
    QEMU_STDERR="$(mktemp)"
    trap 'rm -f "$SERIAL_LOG" "$QEMU_STDERR"' EXIT

    # 起動完了検出パターン
    SERIAL_PATTERN='SabakanOS 起動完了|sabakan:.*#|sabakan login|root@sabakan'

    # QEMU 起動 (-kernel/-initrd で直接ブート)
    # -serial stdio はシリアルポートを標準入出力に接続 (シリアルコンソール用)
    # -display none はグラフィックウィンドウを出さない (CI 向け)
    # -no-reboot は再起動ループを防ぐ
    # -device isa-debug-exit,iobase=0xf4,iosize=0x04 はゲストからの終了通知用
    # -append でカーネルコマンドラインを指定 (console=ttyS0 でシリアルコンソール有効化)
    set +e
    timeout "${QEMU_TIMEOUT}" qemu-system-x86_64 \
        -M q35 \
        -m 512M \
        -cpu qemu64 \
        -kernel "$KERNEL" \
        -initrd "$INITRAMFS" \
        -append "console=ttyS0,115200 earlyprintk=vga root=/dev/ram0 rw" \
        -serial stdio \
        -display none \
        -no-reboot \
        -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
        2>"$QEMU_STDERR" | tee "$SERIAL_LOG"
    QEMU_EXIT_CODE=${PIPESTATUS[0]}
    set -e

    # キャプチャしたシリアル出力を標準出力にも反映 (tee しているので既に出ているが念のため)
    if [ -f "$SERIAL_LOG" ]; then
        cat "$SERIAL_LOG"
    fi

    # 起動完了検出
    if [ -f "$SERIAL_LOG" ] && grep -qE "$SERIAL_PATTERN" "$SERIAL_LOG"; then
        log "ブート成功: シリアル出力から起動完了/シェルプロンプトを検出"
        exit 0
    fi

    if [ -s "$QEMU_STDERR" ]; then
        echo "=== QEMU STDERR ==="
        cat "$QEMU_STDERR"
    fi

    if [ "$QEMU_EXIT_CODE" -eq 124 ] || [ "$QEMU_EXIT_CODE" -eq 137 ]; then
        die "QEMU 起動がタイムアウトしました (${QEMU_TIMEOUT}秒)"
    elif [ "$QEMU_EXIT_CODE" -ne 0 ]; then
        die "QEMU が異常終了しました (終了コード: $QEMU_EXIT_CODE)"
    else
        die "ブート失敗: シリアル出力に起動完了/シェルプロンプトが検出されませんでした"
    fi
}

main "$@"
