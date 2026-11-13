# SabakanOS

[![CI](https://github.com/ryotagtagtag-wq/sabakan-os/actions/workflows/ci.yml/badge.svg)](https://github.com/ryotagtagtag-wq/sabakan-os/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A lightweight, fast Linux-based operating system with built-in Japanese language support.

## Overview

SabakanOS is a lightweight Linux distribution for developers built on three ideas: "canned" (compact and hard to break), "mackerel" (server / development), and "sabai" (clean, minimal design).

Mainstream lightweight distributions (Alpine, Void, Arch and others) do not ship a Japanese desktop by default. SabakanOS targets the following three goals.

- **A lightweight base system** — a minimal musl + BusyBox + OpenRC configuration
- **Japanese support as standard** — `ja_JP.UTF-8`, `Asia/Tokyo`, jp106 keyboard, Mozc, Noto CJK
- **Reproducible builds** — pinned versions, a `make`-driven build, and continuous verification in CI

Key components:

| Layer | Choice |
|-------|--------|
| Kernel | Linux 6.18.63 (kernel.org LTS, x86_64) |
| C library | musl |
| Base utilities / shell | BusyBox (`/bin/sh` is ash) |
| Init | OpenRC |
| Package management | apk (Alpine compatible, APKBUILD format) |
| Bootloader | Limine (BIOS / UEFI) |
| Root filesystem generation | Buildroot 2026.08.1 (falls back to a skeleton when unavailable) |

## Current Status

**Early development (v0.1.0-dev).** Lanes A through E are implementing in parallel.

| Feature | Status | Where it lives |
|---------|--------|----------------|
| Kernel build | Implemented | `make build-kernel` → `build/linux-6.18.63/` |
| Root filesystem generation | Implemented (skeleton) | `make build-rootfs` → `rootfs/` |
| ISO generation | Implemented | `scripts/build-iso.sh` → `build/sabakanos.iso` |
| QEMU boot check | Implemented | `scripts/run-qemu.sh` |
| Japanese environment (locale, IME, fonts) | Designed, not bundled | [`docs/requirements.md`](docs/requirements.md) FR-020 to FR-024 |
| Installer (`sabakan-install`) | Not implemented | Writing the image with `dd` instead |
| `make iso` / `make install` / `make test` | Not implemented | Run the scripts above directly |

> For detailed progress and the hand-off conditions between implementation lanes, see chapter 6 of [`docs/requirements.md`](docs/requirements.md).

## Requirements

### Build Host

| Item | Requirement |
|------|-------------|
| OS | Linux x86_64 (Ubuntu 24.04 / Debian 12 recommended), or macOS |
| CPU | 2 cores or more (4 cores or more recommended) |
| Memory | 4GB or more (8GB recommended) |
| Disk | 10GB or more free (including kernel sources and build intermediates) |
| Tools | GNU Make 4.0 or later (`gmake` on macOS), `curl`, `xz` |

On macOS the stock `make` (3.81) is not enough for the kernel build, so use `gmake` from `brew install make` (`scripts/build-kernel.sh` prefers it automatically). Without an x86_64 Linux cross compiler, kernel compilation is skipped and the build exits successfully after preparing `.config`.

### Target

| Item | Requirement |
|------|-------------|
| Architecture | x86_64 (BIOS / UEFI) |
| Memory | 512MB or more |
| Storage | 4GB or more (2GB or more for USB media) |

## Quick Start

```bash
git clone https://github.com/ryotagtagtag-wq/sabakan-os.git
cd sabakan-os

# 1. Install build dependencies (Ubuntu / Debian)
sudo apt-get update
sudo apt-get install -y build-essential bc bison flex libelf-dev libssl-dev \
  cpio kmod rsync curl wget xz-utils git make zstd \
  xorriso mtools dosfstools

# 2. Build the kernel and the root filesystem
make build-kernel
make build-rootfs

# 3. Generate the ISO (after staging the kernel and Limine in place)
mkdir -p build/kernel
cp build/linux-6.18.63/arch/x86/boot/bzImage build/kernel
./scripts/build-iso.sh

# 4. Verify the boot in QEMU
./scripts/run-qemu.sh
```

## Build Instructions

### 1. Get the Repository

```bash
git clone https://github.com/ryotagtagtag-wq/sabakan-os.git
cd sabakan-os
```

### 2. Install Build Dependencies

**Ubuntu / Debian**

```bash
sudo apt-get update
sudo apt-get install -y build-essential bc bison flex libelf-dev libssl-dev \
  cpio kmod rsync curl wget xz-utils git make zstd \
  xorriso mtools dosfstools
```

**Fedora**

```bash
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y bc bison flex elfutils-libelf-devel openssl-devel \
  cpio rsync curl wget xz git make zstd xorriso mtools dosfstools
```

**Arch Linux**

```bash
sudo pacman -S --needed base-devel bc bison flex libelf openssl cpio rsync \
  curl wget xz git make zstd xorriso mtools dosfstools
```

**macOS**

```bash
brew install make xz xorriso
# Limine must be obtained manually (see below)
```

### 3. Build Targets

| Target | Status | Description | Output |
|--------|--------|-------------|--------|
| `make help` | Implemented | List the available targets | — |
| `make build-kernel` | Implemented | Fetch Linux 6.18.63, apply `config/kernel-defconfig`, and build | `build/linux-6.18.63/arch/x86/boot/bzImage` |
| `make build-rootfs` | Implemented | Generate the root filesystem from the Buildroot defconfig or the skeleton | `rootfs/` |
| `make clean` | Implemented | Remove `build/`, `rootfs/` and `tool/` | — |
| `make iso` | Not implemented | Run `./scripts/build-iso.sh` directly for now | `build/sabakanos.iso` |
| `make test` | Not implemented | Run `./scripts/run-qemu.sh` directly for now | — |
| `make install` | Not implemented | Write the ISO with `dd` for now (see below) | — |
| `make source-bundle` | Not implemented | Generate the distributable source bundle (specified in [`docs/source-flow.md`](docs/source-flow.md)) | `build/source/` |

> `make all` is an alias for `help` (it does not build anything).

### 4. Building the Kernel

```bash
make build-kernel
```

`scripts/build-kernel.sh` performs the following steps.

1. Fetch `linux-6.18.63.tar.xz` from kernel.org (unpacked into `build/`)
2. Apply `config/kernel-defconfig` to `.config` (`olddefconfig`)
3. Compile with `make bzImage`
4. Emit `build/linux-6.18.63/arch/x86/boot/bzImage`

Expect 10 to 20 minutes on 4 cores. On a host without a cross compiler, the build stops after step 3 and exits successfully.

### 5. Generating the Root Filesystem

```bash
make build-rootfs
```

`scripts/build-rootfs.sh` uses the Buildroot (musl / x86_64) defconfig when it can apply it, and otherwise generates a base structure of its own. Either way, `rootfs/` ends up with the following contents.

| Path | Contents |
|------|----------|
| `rootfs/init` | The initial process that becomes PID 1 |
| `rootfs/bin/sh` | Symbolic link to `busybox` |
| `rootfs/etc/passwd`, `group`, `shadow` | Skeleton user information |
| `rootfs/etc/inittab`, `init.d/rcS` | Boot scripts |
| `rootfs/etc/hostname` | `sabakan` |
| `rootfs/{bin,sbin,etc,usr,var,proc,sys,dev,boot,home,root,tmp,opt}` | Directory structure |

The `busybox` binary itself is installed by Buildroot or by a separate package installation.

### 6. Generating the ISO Image

```bash
./scripts/build-iso.sh
```

ISO generation needs the following inputs. The script searches the candidate paths automatically.

| Input | Candidate paths | Notes |
|-------|-----------------|-------|
| Kernel | `build/kernel`, `build/bzImage`, `rootfs/boot/kernel` | `make build-kernel` writes `build/linux-6.18.63/arch/x86/boot/bzImage`, so copy it to `build/kernel` |
| initramfs | `build/initramfs.img`, `build/initrd.img` | Optional. The ISO can be generated without it |
| Limine binaries | `build/limine/`, `boot/limine/`, `third_party/limine/`, `$LIMINE_DIR` | `limine-bios.sys` and `limine-efi.sys` are required |
| Configuration | `boot/limine.cfg` | Boot entry definitions |
| Tool | `xorriso` or `grub-mkrescue` | Used to generate the ISO |

Obtain Limine from the [upstream releases](https://github.com/limine-bootloader/limine/releases) and stage it as follows.

```bash
mkdir -p build/limine
# Place limine-bios.sys and limine-efi.sys from the extracted archive
cp /path/to/limine/limine-bios.sys /path/to/limine/limine-efi.sys build/limine/
```

The output is `build/sabakanos.iso`, a hybrid image that boots on both BIOS and UEFI.

### 7. Verifying the Boot in QEMU

```bash
./scripts/run-qemu.sh
# To change the options
QEMU_OPTS="-m 4G" ./scripts/run-qemu.sh
```

Boot logs stream to the serial console. Success means a shell prompt appears after the boot-complete message that `rootfs/etc/init.d/rcS` prints (`SabakanOS 起動完了`, "SabakanOS boot complete").

## Installation

### Writing to a USB Drive

```bash
lsblk                                  # Confirm the device name to write to
sudo dd if=build/sabakanos.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

GUI tools such as balenaEtcher, Rufus (Windows) or Ventoy work as well.

> **Warning**: `dd` overwrites the entire contents of the device you name. Always point `of=` at the USB drive, and confirm the device with `lsblk` before running the command.

### Booting

1. Insert the USB drive and power on the machine.
2. On UEFI systems, pick the USB drive from the boot menu (BIOS systems boot from it automatically).
3. The Limine menu appears and the default entry boots after 2 seconds.

On boot, `/init` runs as PID 1 and starts a shell (`/bin/sh`) directly. No login prompt is shown. The `root` password is locked (`*`), so set one if you need it.

```sh
passwd root
```

### Installing to a Disk

The installer (`sabakan-install`) is not implemented. For now, deploy manually from a live boot.

```bash
# Prepare the installation target (example: mount /dev/sda1 on /mnt)
mount /dev/sda1 /mnt

# Copy the root filesystem
cp -a /run/rootfs/. /mnt/

# Place the bootloader and the kernel (see boot/limine.cfg)
mkdir -p /mnt/boot
cp /boot/kernel /mnt/boot/

# Unmount and reboot
sync
umount /mnt
reboot
```

For the detailed procedure and acceptance criteria, see FR-014 in [`docs/requirements.md`](docs/requirements.md).

## Japanese Environment Setup

The Japanese environment (locale, IME, fonts) is not bundled in the ISO at this time. The steps below describe a manual setup. Substitute the package names used by the apk repository you are running.

### Locale

```bash
# Install the locale definitions (Alpine based systems)
apk add musl-locales musl-locales-lang

# Enable ja_JP.UTF-8
echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen 2>/dev/null || true

# System-wide default locale
cat > /etc/locale.conf <<'EOF'
LANG=ja_JP.UTF-8
LC_TIME=ja_JP.UTF-8
LC_NUMERIC=ja_JP.UTF-8
LC_MONETARY=ja_JP.UTF-8
LC_PAPER=ja_JP.UTF-8
LC_MEASUREMENT=ja_JP.UTF-8
EOF
```

### Time Zone

```bash
apk add tzdata
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
echo 'Asia/Tokyo' > /etc/timezone
```

### Keyboard Layout (jp106)

```bash
cat > /etc/vconsole.conf <<'EOF'
KEYMAP=jp106
EOF
```

When using `busybox loadkmap`, place the jp106 keymap at `/etc/keymaps/jp106.map`.

### Japanese Input (Mozc)

```bash
apk add ibus ibus-mozc font-noto-cjk

# For X11 sessions
cat >> ~/.xprofile <<'EOF'
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx
EOF

# For Wayland sessions
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/ibus.conf <<'EOF'
GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
EOF
```

To use Fcitx5, replace `ibus` with `fcitx5 fcitx5-mozc` and set the environment variables to `fcitx`.

### Japanese Fonts

```bash
apk add font-noto-cjk font-noto-cjk-extra
fc-cache -fv
fc-match "Noto Sans CJK JP"
```

Add Cica or Ricty Diminished if you need monospaced fonts. If you bundle or modify fonts, mind the Reserved Font Name condition of SIL OFL 1.1 ([`docs/license.md`](docs/license.md)).

### Verifying the Configuration

```bash
locale                    # Is LANG=ja_JP.UTF-8?
date                      # Is the time shown in JST?
cat /etc/vconsole.conf    # Is KEYMAP=jp106?
echo "日本語入力のテスト"  # Can you convert it?
```

## Directory Layout

```text
sabakan-os/
├── README.md                  # This file
├── LICENSE                    # License of the project itself (MIT)
├── Makefile                   # Build entry point (lane A)
├── .github/workflows/         # GitHub Actions CI / release (lane E)
├── boot/
│   └── limine.cfg             # Limine bootloader configuration (lane B)
├── config/
│   ├── buildroot-defconfig    # Buildroot configuration (lane A)
│   ├── kernel-defconfig       # Kernel configuration fragment (lane A)
│   └── packages.txt           # Base package list (lane C)
├── scripts/
│   ├── build-kernel.sh        # Kernel build (lane A)
│   ├── build-rootfs.sh        # Root filesystem generation (lane A)
│   ├── build-iso.sh           # ISO generation (lane B)
│   └── run-qemu.sh            # QEMU boot (lane B)
├── packages/
│   ├── APKBUILD.example       # APKBUILD template (lane C)
│   └── sabakan-base/APKBUILD  # Meta package (lane C)
├── docs/                      # Requirements, license policy, source provision flow (lane E)
│   ├── requirements.md
│   ├── license.md
│   ├── source-flow.md
│   └── source-manifest.example.tsv
├── iso/
│   └── COPYING                # License list and pointers for bundled OSS (lane E)
├── build/                     # Build intermediates and ISO (not tracked by Git)
└── rootfs/                    # Root filesystem (not tracked by Git)
```

`build/` and `rootfs/` are build artifacts and are therefore excluded from Git. Only `iso/COPYING` is tracked as an exception.

## CI

GitHub Actions runs the following checks automatically.

| Workflow | Trigger | Contents |
|----------|---------|----------|
| `.github/workflows/ci.yml` | push / pull request / manual | Documentation checks, license checks, `make build-kernel`, `make build-rootfs`, ISO build (informational) |
| `.github/workflows/release.yml` | `v*.*.*` tag push | Run CI, attach the ISO and the source bundle, create the Release |

The ISO build job currently runs as **informational (a failure does not turn the whole CI red)**, because kernel artifact hand-off and Limine acquisition are not yet wired between lanes. It becomes a required job once that wiring is complete.

To run the same checks locally:

```bash
make build-kernel
make build-rootfs
test -f iso/COPYING && test -f docs/requirements.md && test -f docs/license.md
```

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `make: *** No rule to make target 'iso'` | `make iso` is not implemented. Run `./scripts/build-iso.sh` directly |
| The kernel Makefile fails with `*** missing separator` | Caused by macOS `make` 3.81. Install `gmake` with `brew install make` |
| The kernel build ends with a "skipping compilation" message | No x86_64 Linux cross compiler is available. Run on a Linux host or inside Docker |
| `bc: command not found` / `flex: not found` | Kernel build dependencies are missing. Install `bc`, `bison`, `flex`, `libelf-dev` and `libssl-dev` |
| The Buildroot download fails | With restricted network access the script switches to skeleton generation automatically. Check the `[警告]` (warning) lines in the log |
| `ISO 作成ツールが見つかりません` (no ISO creation tool found) | Install `xorriso` (macOS: `brew install xorriso`) |
| `Limine ブートローダ本体が見つかりません` (Limine binaries not found) | Place `limine-bios.sys` and `limine-efi.sys` in `build/limine/`, or set `LIMINE_DIR` |
| `カーネルイメージが見つかりません` (kernel image not found) | Run `cp build/linux-6.18.63/arch/x86/boot/bzImage build/kernel` |
| `rootfs/bin/sh` is a broken link | The `busybox` binary is missing. Wait for the Buildroot build to finish, or place `busybox` in `rootfs/bin/` |
| No shell appears after booting from the ISO | Check `KERNEL_PATH` and `CMDLINE` in `boot/limine.cfg`, and the staged `boot/kernel` |

## Contributing

This repository is developed in parallel across lanes.

| Lane | Area | Main files owned |
|------|------|------------------|
| A | Build system, kernel, root filesystem | `Makefile`, `scripts/build-kernel.sh`, `scripts/build-rootfs.sh`, `config/buildroot-defconfig`, `config/kernel-defconfig` |
| B | Boot, ISO, QEMU | `boot/`, `scripts/build-iso.sh`, `scripts/run-qemu.sh` |
| C | Packages, Japanese environment | `packages/`, `config/packages.txt` |
| D | Additional implementation (installer, system configuration and so on) | Files in the assigned area |
| E | Documentation, CI, releases, license compliance | `README.md`, `docs/`, `.github/workflows/`, `iso/COPYING` |

Ground rules for contributions:

- Do not commit secrets (API keys, tokens, certificates)
- When you bundle new OSS, update `iso/COPYING` and [`docs/license.md`](docs/license.md) in the same change
- Keep `make build-kernel` and `make build-rootfs` working

## License

The SabakanOS project itself — its build scripts, configuration files, and documentation — is released under the [MIT License](LICENSE).

Bundled third-party software keeps its own license. The generated ISO image contains OSS such as the Linux kernel (GPL-2.0-only), BusyBox (GPL-2.0-only), apk-tools (GPL-2.0-only), OpenRC (BSD-2-Clause), musl (MIT) and Limine (BSD-2-Clause). Each copyright notice and full license text is installed under `/usr/share/licenses/` on the ISO, and [`iso/COPYING`](iso/COPYING) lists them all.

The MIT license of this repository does not relicense the bundled OSS. The repository and its ISO image are two different distribution channels:

- **The repository** is MIT-licensed source code. Cloning, reading and modifying it does not involve any GPL or LGPL obligation.
- **The ISO image** is a binary distribution of multiple licenses. Distributing it — by download, on physical media, or by any other means — triggers the GPL and LGPL source provision obligations for every covered component (the Linux kernel, BusyBox, apk-tools, alpine-baselayout and others).

Whenever an ISO is distributed, the complete corresponding source code must be made available at the same time. The release workflow attaches a source bundle alongside the ISO; the available methods, the manifest format and the pre-release checklist are described in [`docs/source-flow.md`](docs/source-flow.md), and the obligations per license are listed in [`docs/license.md`](docs/license.md).

## Documentation

| Document | Contents |
|----------|----------|
| [`docs/requirements.md`](docs/requirements.md) | Functional and non-functional requirements, milestones, inter-lane interfaces |
| [`docs/license.md`](docs/license.md) | License inventory of bundled OSS, distribution obligations, compliance checklist |
| [`docs/source-flow.md`](docs/source-flow.md) | Source provision flow for distribution, manifest operations, release procedure |
| [`docs/source-manifest.example.tsv`](docs/source-manifest.example.tsv) | Template for the source manifest |
| [`iso/COPYING`](iso/COPYING) | License list of the OSS bundled in the ISO, with pointers to individual license files |
