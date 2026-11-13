#!/bin/bash
#
# scripts/build-iso.sh — SabakanOS ブート可能 ISO イメージ生成スクリプト (レーンB 所有)
#
# 概要:
#   Linux カーネル + initramfs + Limine ブートローダ設定をパッケージ化し、
#   ブート可能な ISO イメージ (x86_64 BIOS + UEFI) を生成する。
#
# 生成物:
#   build/sabakanos.iso
#
# 依存:
#   - xorriso (推奨) または grub-mkrescue
#   - Limine ブートローダ本体 (limine-bios.sys / limine-efi.sys)
#   - Linux カーネルイメージ (build/kernel または rootfs/boot/kernel)
#   - initramfs (build/initramfs.img または build/initrd.img)
#
# 使い方:
#   ./scripts/build-iso.sh
#
# 注意:
#   本スクリプトは Makefile / config/ / rootfs/ など他レーン所有ファイルには
#   触れず、build/ 配下の成果物のみを参照・出力する。

set -euo pipefail

# ---------------------------------------------------------------------------
# パス設定 (スクリプト位置からプロジェクトルートを解決)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
ISO_OUT="$BUILD_DIR/sabakanos.iso"
STAGING_DIR="$BUILD_DIR/iso_root"

LIMINE_CFG="$PROJECT_ROOT/boot/limine.cfg"

# ---------------------------------------------------------------------------
# ユーティリティ
# ---------------------------------------------------------------------------
log()  { printf '[build-iso] %b\n' "$*"; }
warn() { printf '[build-iso][WARN] %b\n' "$*" >&2; }
die()  { printf '[build-iso][ERROR] %b\n' "$*" >&2; exit 1; }

# 必須コマンドの存在チェック
require_cmd() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        die "必須コマンドが見つかりません: $cmd (インストールしてから再実行してください)"
    fi
}

# ---------------------------------------------------------------------------
# 依存ツールのチェック (ISO 作成に xorriso または grub-mkrescue のいずれかが必要)
# ---------------------------------------------------------------------------
check_build_tools() {
    if command -v xorriso >/dev/null 2>&1; then
        BUILD_TOOL="xorriso"
        log "ISO 作成ツール: xorriso"
    elif command -v grub-mkrescue >/dev/null 2>&1; then
        BUILD_TOOL="grub-mkrescue"
        log "ISO 作成ツール: grub-mkrescue"
    else
        die "ISO 作成ツールが見つかりません。以下のいずれかをインストールしてください。\n"\
            "  macOS: brew install xorriso  (または grub)\n"\
            "  Ubuntu/Debian: sudo apt-get install xorriso  (または grub-pc-bin grub-common)"
    fi
}

# ---------------------------------------------------------------------------
# Limine ブートローダ本体の解決
#   返り値: LIMINE_BIOS (limine-bios.sys のパス), LIMINE_EFI (limine-efi.sys のパス)
# ---------------------------------------------------------------------------
resolve_limine_binaries() {
    LIMINE_BIOS=""
    LIMINE_EFI=""

    # 候補ディレクトリ (環境変数 LIMAINE_DIR で上書き可能)
    local limine_dirs=()
    if [[ -n "${LIMINE_DIR:-}" ]]; then
        limine_dirs+=("$LIMINE_DIR")
    fi
    limine_dirs+=(
        "$BUILD_DIR/limine"
        "$PROJECT_ROOT/boot/limine"
        "$PROJECT_ROOT/third_party/limine"
        "/usr/local/share/limine"
        "/opt/limine"
    )

    for dir in "${limine_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        if [[ -z "$LIMINE_BIOS" && -f "$dir/limine-bios.sys" ]]; then
            LIMINE_BIOS="$dir/limine-bios.sys"
        fi
        if [[ -z "$LIMINE_EFI" && -f "$dir/limine-efi.sys" ]]; then
            LIMINE_EFI="$dir/limine-efi.sys"
        fi
        [[ -n "$LIMINE_BIOS" && -n "$LIMINE_EFI" ]] && break
    done

    if [[ -z "$LIMINE_BIOS" || -z "$LIMINE_EFI" ]]; then
        die "Limine ブートローダ本体が見つかりません。\n"\
            "  入手: https://github.com/limine-bootloader/limine/releases\n"\
            "  必要ファイル: limine-bios.sys, limine-efi.sys\n"\
            "  環境変数 LIMINE_DIR に本体ディレクトリを指定するか、\n"\
            "  build/limine や boot/limine に配置してください。"
    fi

    log "Limine BIOS: $LIMINE_BIOS"
    log "Limine EFI : $LIMINE_EFI"
}

# ---------------------------------------------------------------------------
# カーネル・initramfs の解決
# ---------------------------------------------------------------------------
resolve_kernel_and_initramfs() {
    KERNEL=""
    INITRAMFS=""

    # カーネル候補
    local kernel_candidates=(
        "$BUILD_DIR/kernel"
        "$BUILD_DIR/kernel.elf"
        "$BUILD_DIR/bzImage"
        "$PROJECT_ROOT/rootfs/boot/kernel"
        "$PROJECT_ROOT/rootfs/boot/kernel.elf"
        "$PROJECT_ROOT/rootfs/boot/bzImage"
    )
    for c in "${kernel_candidates[@]}"; do
        if [[ -f "$c" ]]; then
            KERNEL="$c"
            break
        fi
    done

    # initramfs 候補
    local initramfs_candidates=(
        "$BUILD_DIR/initramfs.img"
        "$BUILD_DIR/initrd.img"
        "$BUILD_DIR/initramfs"
        "$PROJECT_ROOT/rootfs/boot/initramfs.img"
        "$PROJECT_ROOT/rootfs/boot/initrd.img"
    )
    for c in "${initramfs_candidates[@]}"; do
        if [[ -f "$c" ]]; then
            INITRAMFS="$c"
            break
        fi
    done

    if [[ -z "$KERNEL" ]]; then
        die "カーネルイメージが見つかりません。\n"\
            "  他レーン (カーネルビルド) の成果物を build/ または rootfs/boot/ に配置してください。\n"\
            "  候補: build/kernel, build/kernel.elf, rootfs/boot/kernel"
    fi
    if [[ -z "$INITRAMFS" ]]; then
        warn "initramfs が見つかりません (任意)。initrd なしでブートします。\n"\
            "  候補: build/initramfs.img, build/initrd.img"
    fi

    log "カーネル: $KERNEL"
    if [[ -n "$INITRAMFS" ]]; then log "initramfs: $INITRAMFS"; fi
}

# ---------------------------------------------------------------------------
# ISO ステージングディレクトリの構築
# ---------------------------------------------------------------------------
stage_iso_root() {
    log "ステージングディレクトリを準備: $STAGING_DIR"
    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR/boot"
    mkdir -p "$STAGING_DIR/EFI/BOOT"

    # Limine 設定
    cp "$LIMINE_CFG" "$STAGING_DIR/boot/limine.cfg"
    log "コピー: boot/limine.cfg"

    # Limine BIOS ブートローダ
    cp "$LIMINE_BIOS" "$STAGING_DIR/boot/limine-bios.sys"
    log "コピー: boot/limine-bios.sys"

    # Limine EFI ブートローダ (EFI/BOOT/BOOTX64.EFI)
    cp "$LIMINE_EFI" "$STAGING_DIR/EFI/BOOT/BOOTX64.EFI"
    log "コピー: EFI/BOOT/BOOTX64.EFI (limine-efi.sys から)"

    # カーネル
    cp "$KERNEL" "$STAGING_DIR/boot/kernel"
    log "コピー: boot/kernel ($KERNEL)"

    # initramfs (存在する場合)
    if [[ -n "$INITRAMFS" ]]; then
        cp "$INITRAMFS" "$STAGING_DIR/boot/initramfs.img"
        log "コピー: boot/initramfs.img ($INITRAMFS)"
    fi
}

# ---------------------------------------------------------------------------
# ISO イメージ生成 (xorriso / grub-mkrescue)
# ---------------------------------------------------------------------------
build_iso_xorriso() {
    log "ISO イメージを生成中 (xorriso): $ISO_OUT"
    rm -f "$ISO_OUT"

    xorriso -as mkisofs \
        -o "$ISO_OUT" \
        -V 'SABAKANOS' \
        -volid 'SABAKANOS' \
        -b boot/limine-bios.sys \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --efi-boot EFI/BOOT/BOOTX64.EFI \
        -efi-boot-part --efi-boot-image --protective-msdos-label \
        "$STAGING_DIR"

    if [[ ! -f "$ISO_OUT" ]]; then
        die "ISO イメージの生成に失敗しました: $ISO_OUT"
    fi

    local size
    size=$(du -h "$ISO_OUT" | cut -f1)
    log "生成完了: $ISO_OUT ($size)"
}

build_iso_grub() {
    log "ISO イメージを生成中 (grub-mkrescue): $ISO_OUT"
    rm -f "$ISO_OUT"

    grub-mkrescue -o "$ISO_OUT" "$STAGING_DIR"

    if [[ ! -f "$ISO_OUT" ]]; then
        die "ISO イメージの生成に失敗しました: $ISO_OUT"
    fi

    local size
    size=$(du -h "$ISO_OUT" | cut -f1)
    log "生成完了: $ISO_OUT ($size)"
}

# ---------------------------------------------------------------------------
# メイン
# ---------------------------------------------------------------------------
main() {
    log "SabakanOS ISO ビルドを開始"
    log "プロジェクトルート: $PROJECT_ROOT"

    check_build_tools
    resolve_limine_binaries
    resolve_kernel_and_initramfs
    stage_iso_root

    if [[ "$BUILD_TOOL" == "xorriso" ]]; then
        build_iso_xorriso
    else
        build_iso_grub
    fi

    log "------------------------------------------------------------"
    log "ISO イメージが生成されました: $ISO_OUT"
    log "次のコマンドで QEMU 起動できます:"
    log "  ./scripts/run-qemu.sh"
    log "------------------------------------------------------------"
}

main "$@"
