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

# アーキテクチャ (EFI ブートローダファイル名に影響: x86_64=BOOTX64.EFI, arm64=BOOTAA64.EFI)
ARCH="${ARCH:-x86_64}"
case "$ARCH" in
    x86_64|amd64) ARCH=x86_64 ;;
    arm64|aarch64) ARCH=arm64 ;;
    *)
        die "未サポートのアーキテクチャ: $ARCH (x86_64 または arm64 を指定してください)"
        ;;
esac
if [[ "$ARCH" == "arm64" ]]; then
    LIMINE_EFI_NAME="BOOTAA64.EFI"
else
    LIMINE_EFI_NAME="BOOTX64.EFI"
fi

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
#   返り値: LIMINE_BIOS_CD (limine-bios-cd.bin のパス / El Torito ブートイメージ),
#           LIMINE_BIOS (limine-bios.sys のパス / 2 段目ペイロード),
#           LIMINE_EFI (limine-efi.sys のパス)
# ---------------------------------------------------------------------------
resolve_limine_binaries() {
    LIMINE_BIOS_CD=""
    LIMINE_BIOS=""
    LIMINE_EFI=""
    LIMINE_UEFI_CD=""
    LIMINE_TOOL=""

    # 候補ディレクトリ (環境変数 LIMINE_DIR で上書き可能)
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
        if [[ -z "$LIMINE_BIOS_CD" && -f "$dir/limine-bios-cd.bin" ]]; then
            LIMINE_BIOS_CD="$dir/limine-bios-cd.bin"
        fi
        if [[ -z "$LIMINE_BIOS" && -f "$dir/limine-bios.sys" ]]; then
            LIMINE_BIOS="$dir/limine-bios.sys"
        fi
        if [[ -z "$LIMINE_EFI" && -f "$dir/limine-efi.sys" ]]; then
            LIMINE_EFI="$dir/limine-efi.sys"
        fi
        if [[ -z "$LIMINE_UEFI_CD" && -f "$dir/limine-uefi-cd.bin" ]]; then
            LIMINE_UEFI_CD="$dir/limine-uefi-cd.bin"
        fi
        if [[ -z "$LIMINE_TOOL" ]]; then
            for tc in "$dir/limine" "$dir/bin/limine" "$dir"/limine-*/bin/limine; do
                if [[ -f "$tc" && -x "$tc" ]]; then
                    LIMINE_TOOL="$tc"
                    break
                fi
            done
        fi
        [[ -n "$LIMINE_BIOS_CD" && -n "$LIMINE_BIOS" ]] && break
    done

    if [[ -z "$LIMINE_BIOS_CD" ]]; then
        warn "Limine El Torito ブートイメージ (limine-bios-cd.bin) が見つかりません。BIOS ブートはスキップします。\n"\
            "  UEFI のみで ISO を生成する場合は問題ありません。\n"\
            "  入手: https://github.com/limine-bootloader/limine/releases"
    fi
    if [[ -z "$LIMINE_BIOS" ]]; then
        warn "Limine 2 段目ペイロード (limine-bios.sys) が見つかりません。BIOS ブートはスキップします。\n"\
            "  入手: https://github.com/limine-bootloader/limine/releases"
    fi

    if [[ -z "$LIMINE_BIOS_CD" && -z "$LIMINE_EFI" ]]; then
        die "ブート可能な Limine バイナリが見つかりません (BIOS も EFI もなし)。\n"\
            "  limine-bios-cd.bin / limine-bios.sys (BIOS) または limine-efi.sys (EFI) のいずれかが必要です。\n"\
            "  入手: https://github.com/limine-bootloader/limine/releases\n"\
            "  環境変数 LIMINE_DIR に本体ディレクトリを指定するか、\n"\
            "  build/limine や boot/limine に配置してください。"
    fi
    if [[ -n "$LIMINE_BIOS_CD" ]]; then
        log "Limine BIOS CD (El Torito ブートイメージ): $LIMINE_BIOS_CD"
    fi
    if [[ -n "$LIMINE_BIOS" ]]; then
        log "Limine BIOS (2 段目ペイロード): $LIMINE_BIOS"
    fi

    if [[ -z "$LIMINE_TOOL" ]]; then
        warn "Limine ツール (limine) が見つかりません。BIOS ブート用の 'limine bios-install' はスキップします。\n"\
            "  build/limine/limine-*/bin/limine に配置してください。"
    else
        log "Limine ツール: $LIMINE_TOOL"
    fi
    if [[ -n "$LIMINE_UEFI_CD" ]]; then
        log "Limine UEFI CD (El Torito EFI ブートイメージ): $LIMINE_UEFI_CD"
    fi
    if [[ -z "$LIMINE_EFI" ]]; then
        warn "Limine EFI (limine-efi.sys) が見つかりません。EFI ブートはスキップし、BIOS ブートのみで ISO を生成します。"
    else
        log "Limine EFI : $LIMINE_EFI"
    fi
}

# ---------------------------------------------------------------------------
# カーネル・initramfs の解決
# ---------------------------------------------------------------------------
resolve_kernel_and_initramfs() {
    KERNEL=""
    INITRAMFS=""

    # カーネル候補 (build-kernel.sh の正規コピーを最優先。build/bzImage はプレースホルダのため最終手段)
    local kernel_candidates=(
        "$BUILD_DIR/kernel-${ARCH}"
        "$BUILD_DIR/linux-6.12.34/arch/x86/boot/bzImage"
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
        die "initramfs が見つかりません (必須)。\n"\
            "  先に 'make build-rootfs' (scripts/build-rootfs.sh) を実行して build/initramfs.img を生成してください。\n"\
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

    # Limine BIOS El Torito ブートイメージ (ブートセクタ用) — BIOS 未入手時はスキップ
    if [[ -n "$LIMINE_BIOS_CD" ]]; then
        cp "$LIMINE_BIOS_CD" "$STAGING_DIR/boot/limine-bios-cd.bin"
        log "コピー: boot/limine-bios-cd.bin"
    else
        log "スキップ: boot/limine-bios-cd.bin (limine-bios-cd.bin 未入手のため)"
    fi

    # Limine BIOS ブートローダ (2 段目ペイロード) — BIOS 未入手時はスキップ
    if [[ -n "$LIMINE_BIOS" ]]; then
        cp "$LIMINE_BIOS" "$STAGING_DIR/boot/limine-bios.sys"
        log "コピー: boot/limine-bios.sys"
    else
        log "スキップ: boot/limine-bios.sys (limine-bios.sys 未入手のため)"
    fi

    # Limine UEFI El Torito ブートイメージ (EFI ブートセクタ用) — limine-uefi-cd.bin が無い場合はスキップ
    if [[ -n "$LIMINE_UEFI_CD" ]]; then
        cp "$LIMINE_UEFI_CD" "$STAGING_DIR/boot/limine-uefi-cd.bin"
        log "コピー: boot/limine-uefi-cd.bin"
    else
        log "スキップ: boot/limine-uefi-cd.bin (limine-uefi-cd.bin 未入手のため)"
    fi

    # Limine EFI ブートローダ (EFI/BOOT/BOOTX64.EFI または BOOTAA64.EFI) — limine-efi.sys が無い場合はスキップ
    if [[ -n "$LIMINE_EFI" ]]; then
        cp "$LIMINE_EFI" "$STAGING_DIR/EFI/BOOT/${LIMINE_EFI_NAME}"
        log "コピー: EFI/BOOT/${LIMINE_EFI_NAME} (limine-efi.sys から)"
    else
        log "スキップ: EFI/BOOT/${LIMINE_EFI_NAME} (limine-efi.sys 未入手のため)"
    fi

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

    # BIOS 利用可否に応じて xorriso オプションを分岐 (BIOS 無し = UEFI のみ)
    if [[ -n "$LIMINE_BIOS_CD" ]]; then
        # BIOS ブート可能: El Torito ブートセクタを BIOS CD に設定
        if [[ -n "$LIMINE_UEFI_CD" ]]; then
            xorriso -as mkisofs \
                -o "$ISO_OUT" \
                -V 'SABAKANOS' \
                -volid 'SABAKANOS' \
                -b boot/limine-bios-cd.bin \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                -eltorito-alt-boot \
                -e boot/limine-uefi-cd.bin \
                -no-emul-boot \
                "$STAGING_DIR"
        elif [[ -n "$LIMINE_EFI" ]]; then
            xorriso -as mkisofs \
                -o "$ISO_OUT" \
                -V 'SABAKANOS' \
                -volid 'SABAKANOS' \
                -b boot/limine-bios-cd.bin \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                --efi-boot "EFI/BOOT/${LIMINE_EFI_NAME}" \
                -efi-boot-part --efi-boot-image --protective-msdos-label \
                "$STAGING_DIR"
        else
            xorriso -as mkisofs \
                -o "$ISO_OUT" \
                -V 'SABAKANOS' \
                -volid 'SABAKANOS' \
                -b boot/limine-bios-cd.bin \
                -no-emul-boot -boot-load-size 4 -boot-info-table \
                "$STAGING_DIR"
        fi
    elif [[ -n "$LIMINE_UEFI_CD" ]]; then
        # UEFI のみ (BIOS なし): El Torito ブートセクタを UEFI CD に設定
        xorriso -as mkisofs \
            -o "$ISO_OUT" \
            -V 'SABAKANOS' \
            -volid 'SABAKANOS' \
            -b boot/limine-uefi-cd.bin \
            -no-emul-boot \
            "$STAGING_DIR"
    elif [[ -n "$LIMINE_EFI" ]]; then
        # UEFI のみ (BIOS なし): --efi-boot で EFI ブートローダを指定
        xorriso -as mkisofs \
            -o "$ISO_OUT" \
            -V 'SABAKANOS' \
            -volid 'SABAKANOS' \
            --efi-boot "EFI/BOOT/${LIMINE_EFI_NAME}" \
            -efi-boot-part --efi-boot-image --protective-msdos-label \
            "$STAGING_DIR"
    else
        die "BIOS および EFI のいずれも利用できず、ブート可能な ISO を生成できません。"
    fi

    if [[ ! -f "$ISO_OUT" ]]; then
        die "ISO イメージの生成に失敗しました: $ISO_OUT"
    fi

    # Limine BIOS ブート用パッチ適用 (limine bios-install)
    # macOS では Linux x86_64 バイナリが実行できないため、失敗しても警告にとどめる
    # UEFI のみ (BIOS なし) またはツール未入手時はスキップ
    if [[ -n "$LIMINE_TOOL" && -n "$LIMINE_BIOS_CD" ]]; then
        log "Limine BIOS インストールを適用中: $ISO_OUT"
        if ! "$LIMINE_TOOL" bios-install "$ISO_OUT" 2>/tmp/bios-install-err; then
            warn "limine bios-install の適用に失敗しました:\n$(cat /tmp/bios-install-err 2>/dev/null)"
        fi
        rm -f /tmp/bios-install-err
    else
        log "Limine BIOS インストールをスキップ (BIOS なしまたは limine ツール未入手)"
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
