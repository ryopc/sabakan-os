# SabakanOS

[![CI](https://github.com/ryotagtagtag-wq/sabakan-os/actions/workflows/ci.yml/badge.svg)](https://github.com/ryotagtagtag-wq/sabakan-os/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

軽量・高速で、日本語環境を備えた Linux ベースのオペレーティングシステムです。

## 概要

SabakanOS は「缶詰（コンパクトに収まって壊れない）」「鯖（サーバー／開発）」「サバい（潔いミニマル設計）」をコンセプトにした、開発者向けの軽量 Linux ディストリビューションです。

既存の軽量ディストリビューション（Alpine、Void、Arch など）は日本語デスクトップが標準ではありません。SabakanOS は次の 3 点を目指しています。

- **軽量なベースシステム** — musl + BusyBox + OpenRC の最小構成
- **日本語環境の標準搭載** — `ja_JP.UTF-8`、`Asia/Tokyo`、jp106 キーボード、Mozc、Noto CJK
- **再現可能なビルド** — バージョンを固定した `make` ビルドと CI による常時検証

構成の要点:

| 層 | 採用 |
|----|------|
| カーネル | Linux 6.18.63（kernel.org LTS、x86_64） |
| C ライブラリ | musl |
| 基本ユーティリティ / シェル | BusyBox（`/bin/sh` は ash） |
| Init | OpenRC |
| パッケージ管理 | apk（Alpine 互換、APKBUILD 形式） |
| ブートローダー | Limine（BIOS / UEFI） |
| ルートFS生成 | Buildroot 2026.08.1（利用できない場合は雛形を生成） |

## 現在のステータス

**開発初期（v0.1.0-dev）** です。レーンA〜E が並行して実装を進めています。

| 機能 | 状態 | 実体 |
|------|------|------|
| カーネルビルド | 実装済み | `make build-kernel` → `build/linux-6.18.63/` |
| ルートFS生成 | 実装済み（雛形） | `make build-rootfs` → `rootfs/` |
| ISO 生成 | 実装済み | `scripts/build-iso.sh` → `build/sabakanos.iso` |
| QEMU 起動確認 | 実装済み | `scripts/run-qemu.sh` |
| 日本語環境（ロケール・IME・フォント） | 設計済み・未同梱 | [`docs/requirements.md`](docs/requirements.md) FR-020〜FR-024 |
| インストーラ（`sabakan-install`） | 未実装 | `dd` による書き込みで代替 |
| `make iso` / `make install` / `make test` | 未実装 | 上記スクリプトを直接実行する |

> 進捗の詳細と実装レーン間の受け渡し条件は [`docs/requirements.md`](docs/requirements.md) の第 6 章を参照してください。

## 動作要件

### ビルドホスト

| 項目 | 要件 |
|------|------|
| OS | Linux x86_64（Ubuntu 24.04 / Debian 12 推奨）、または macOS |
| CPU | 2 コア以上（4 コア以上推奨） |
| メモリ | 4GB 以上（8GB 推奨） |
| ディスク | 空き 10GB 以上（カーネルソースとビルド中間物を含む） |
| ツール | GNU Make 4.0 以上（macOS では `gmake`）、`curl`、`xz` |

macOS では標準の `make`（3.81）がカーネルビルドに不足するため、`brew install make` で入る `gmake` を使用します（`scripts/build-kernel.sh` が自動で優先します）。x86_64 Linux 向けクロスコンパイラがない場合、カーネルのコンパイルはスキップされ、`.config` の準備までで正常終了します。

### ターゲット

| 項目 | 要件 |
|------|------|
| アーキテクチャ | x86_64（BIOS / UEFI） |
| メモリ | 512MB 以上 |
| ストレージ | 4GB 以上（USB メモリは 2GB 以上） |

## クイックスタート

```bash
git clone https://github.com/ryotagtagtag-wq/sabakan-os.git
cd sabakan-os

# 1. ビルド依存の導入（Ubuntu / Debian の場合）
sudo apt-get update
sudo apt-get install -y build-essential bc bison flex libelf-dev libssl-dev \
  cpio kmod rsync curl wget xz-utils git make zstd \
  xorriso mtools dosfstools

# 2. カーネルとルートFSをビルド
make build-kernel
make build-rootfs

# 3. ISO を生成（カーネルと Limine を所定の場所に配置してから）
mkdir -p build/kernel
cp build/linux-6.18.63/arch/x86/boot/bzImage build/kernel
./scripts/build-iso.sh

# 4. QEMU で起動確認
./scripts/run-qemu.sh
```

## ビルド手順

### 1. リポジトリの取得

```bash
git clone https://github.com/ryotagtagtag-wq/sabakan-os.git
cd sabakan-os
```

### 2. ビルド依存の導入

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
# Limine は手動で入手する（後述）
```

### 3. ビルドターゲット

| ターゲット | 状態 | 説明 | 出力先 |
|------------|------|------|--------|
| `make help` | 実装済み | 利用可能なターゲットの一覧を表示 | — |
| `make build-kernel` | 実装済み | Linux 6.18.63 を取得し、`config/kernel-defconfig` を適用してビルド | `build/linux-6.18.63/arch/x86/boot/bzImage` |
| `make build-rootfs` | 実装済み | Buildroot defconfig または雛形からルートFSを生成 | `rootfs/` |
| `make clean` | 実装済み | `build/`、`rootfs/`、`tool/` を削除 | — |
| `make iso` | 未実装 | 現状は `./scripts/build-iso.sh` を直接実行 | `build/sabakanos.iso` |
| `make test` | 未実装 | 現状は `./scripts/run-qemu.sh` を直接実行 | — |
| `make install` | 未実装 | 現状は `dd` で ISO を書き込む（後述） | — |
| `make source-bundle` | 未実装 | 配布用ソース一式の生成（仕様は [`docs/source-flow.md`](docs/source-flow.md)） | `build/source/` |

> `make all` は `help` の別名です（ビルドは実行しません）。

### 4. カーネルのビルド

```bash
make build-kernel
```

`scripts/build-kernel.sh` が次の処理を行います。

1. kernel.org から `linux-6.18.63.tar.xz` を取得（`build/` に展開）
2. `config/kernel-defconfig` を `.config` に適用（`olddefconfig`）
3. `make bzImage` でコンパイル
4. `build/linux-6.18.63/arch/x86/boot/bzImage` を出力

所要時間の目安は 4 コアで 10〜20 分です。クロスコンパイラがない環境では、3 の手順まで実行して正常終了します。

### 5. ルートファイルシステムの生成

```bash
make build-rootfs
```

`scripts/build-rootfs.sh` は Buildroot（musl / x86_64）の defconfig を適用できる場合はそれを用い、適用できない場合は独自にベース構造を生成します。どちらの場合も `rootfs/` には次の内容が揃います。

| パス | 内容 |
|------|------|
| `rootfs/init` | PID 1 となる初期プロセス |
| `rootfs/bin/sh` | `busybox` へのシンボリックリンク |
| `rootfs/etc/passwd`、`group`、`shadow` | ユーザー情報の雛形 |
| `rootfs/etc/inittab`、`init.d/rcS` | 起動スクリプト |
| `rootfs/etc/hostname` | `sabakan` |
| `rootfs/{bin,sbin,etc,usr,var,proc,sys,dev,boot,home,root,tmp,opt}` | ディレクトリ構造 |

`busybox` 本体は Buildroot または別途のパッケージ導入で配置します。

### 6. ISO イメージの生成

```bash
./scripts/build-iso.sh
```

ISO 生成には次の入力が必要です。スクリプトは所定の候補パスを自動で探します。

| 入力 | 候補パス | 補足 |
|------|----------|------|
| カーネル | `build/kernel`、`build/bzImage`、`rootfs/boot/kernel` | `make build-kernel` の出力は `build/linux-6.18.63/arch/x86/boot/bzImage` のため、`build/kernel` へコピーする |
| initramfs | `build/initramfs.img`、`build/initrd.img` | 任意。なくても生成できる |
| Limine 本体 | `build/limine/`、`boot/limine/`、`third_party/limine/`、`$LIMINE_DIR` | `limine-bios.sys` と `limine-efi.sys` が必要 |
| 設定 | `boot/limine.cfg` | ブートエントリ定義 |
| ツール | `xorriso` または `grub-mkrescue` | ISO の生成に使用 |

Limine は [上流のリリース](https://github.com/limine-bootloader/limine/releases) から取得し、次のように配置します。

```bash
mkdir -p build/limine
# 展開したアーカイブから limine-bios.sys と limine-efi.sys を配置する
cp /path/to/limine/limine-bios.sys /path/to/limine/limine-efi.sys build/limine/
```

生成物は `build/sabakanos.iso` です。BIOS / UEFI の両方で起動できるハイブリッド構成になります。

### 7. QEMU での起動確認

```bash
./scripts/run-qemu.sh
# オプションを変える場合
QEMU_OPTS="-m 4G" ./scripts/run-qemu.sh
```

シリアルコンソールに起動ログが流れ、`SabakanOS 起動完了` の後にシェルプロンプトが表示されれば成功です。

## インストール手順

### USB メモリへ書き込む

```bash
lsblk                                  # 書き込み先のデバイス名を確認する
sudo dd if=build/sabakanos.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

GUI ツールを使う場合は balenaEtcher、Rufus（Windows）、Ventoy でも書き込めます。

> **警告**: `dd` は指定したデバイスの内容を完全に上書きします。`of=` には必ず USB メモリを指定し、`lsblk` で確認してから実行してください。

### 起動する

1. USB メモリを挿して電源を入れる。
2. UEFI 環境では起動メニューから USB を選択する（BIOS 環境では自動的に起動する）。
3. Limine のメニューが表示され、既定エントリが 2 秒で起動する。

起動すると `/init` が PID 1 として動作し、そのままシェル（`/bin/sh`）が起動します。ログインプロンプトは表示されません。`root` のパスワードはロック（`*`）されているため、必要に応じて次を実行して設定してください。

```sh
passwd root
```

### ディスクへインストールする

インストーラ（`sabakan-install`）は未実装です。現時点では Live 起動した環境から手動で展開します。

```bash
# インストール先を用意する（例: /dev/sda1 を /mnt にマウント）
mount /dev/sda1 /mnt

# ルートFSをコピーする
cp -a /run/rootfs/. /mnt/

# ブートローダーとカーネルを配置する（boot/limine.cfg を参照）
mkdir -p /mnt/boot
cp /boot/kernel /mnt/boot/

# アンマウントして再起動する
sync
umount /mnt
reboot
```

手順の詳細と受け入れ条件は [`docs/requirements.md`](docs/requirements.md) の FR-014 を参照してください。

## 日本語環境設定

日本語環境（ロケール、IME、フォント）は現時点では ISO に同梱されていません。以下は手動で設定する場合の手順です。パッケージ名は採用している apk のものに読み替えてください。

### ロケール

```bash
# ロケール定義の導入（Alpine 系の場合）
apk add musl-locales musl-locales-lang

# ja_JP.UTF-8 を有効化
echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen 2>/dev/null || true

# システム全体の既定ロケール
cat > /etc/locale.conf <<'EOF'
LANG=ja_JP.UTF-8
LC_TIME=ja_JP.UTF-8
LC_NUMERIC=ja_JP.UTF-8
LC_MONETARY=ja_JP.UTF-8
LC_PAPER=ja_JP.UTF-8
LC_MEASUREMENT=ja_JP.UTF-8
EOF
```

### タイムゾーン

```bash
apk add tzdata
ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
echo 'Asia/Tokyo' > /etc/timezone
```

### キーボードレイアウト（jp106）

```bash
cat > /etc/vconsole.conf <<'EOF'
KEYMAP=jp106
EOF
```

`busybox loadkmap` を使う場合は、jp106 のキーマップを `/etc/keymaps/jp106.map` に配置します。

### 日本語入力（Mozc）

```bash
apk add ibus ibus-mozc font-noto-cjk

# X11 セッションの場合
cat >> ~/.xprofile <<'EOF'
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx
EOF

# Wayland セッションの場合
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/ibus.conf <<'EOF'
GTK_IM_MODULE=ibus
QT_IM_MODULE=ibus
XMODIFIERS=@im=ibus
EOF
```

Fcitx5 を使う場合は `ibus` を `fcitx5 fcitx5-mozc` に、環境変数を `fcitx` に読み替えます。

### 日本語フォント

```bash
apk add font-noto-cjk font-noto-cjk-extra
fc-cache -fv
fc-match "Noto Sans CJK JP"
```

等幅フォントが必要な場合は Cica や Ricty Diminished を追加します。フォントの同梱・改変を行う場合は SIL OFL 1.1 の Reserved Font Name の条件に注意してください（[`docs/license.md`](docs/license.md)）。

### 設定の確認

```bash
locale                    # LANG=ja_JP.UTF-8 になっているか
date                      # JST で表示されるか
cat /etc/vconsole.conf    # KEYMAP=jp106 か
echo "日本語入力のテスト"  # 変換できるか
```

## ディレクトリ構成

```text
sabakan-os/
├── README.md                  # 本ファイル
├── LICENSE                    # プロジェクト本体のライセンス（MIT）
├── Makefile                   # ビルドのエントリポイント（レーンA）
├── .github/workflows/         # GitHub Actions CI / リリース（レーンE）
├── boot/
│   └── limine.cfg             # Limine ブートローダ設定（レーンB）
├── config/
│   ├── buildroot-defconfig    # Buildroot 設定（レーンA）
│   ├── kernel-defconfig       # カーネル設定の差分（レーンA）
│   └── packages.txt           # ベースパッケージ一覧（レーンC）
├── scripts/
│   ├── build-kernel.sh        # カーネルビルド（レーンA）
│   ├── build-rootfs.sh        # ルートFS生成（レーンA）
│   ├── build-iso.sh           # ISO 生成（レーンB）
│   └── run-qemu.sh            # QEMU 起動（レーンB）
├── packages/
│   ├── APKBUILD.example       # APKBUILD のひな形（レーンC）
│   └── sabakan-base/APKBUILD  # メタパッケージ（レーンC）
├── docs/                      # 要件定義・ライセンス方針・ソース提供フロー（レーンE）
│   ├── requirements.md
│   ├── license.md
│   ├── source-flow.md
│   └── source-manifest.example.tsv
├── iso/
│   └── COPYING                # 同梱 OSS のライセンス一覧とポインタ（レーンE）
├── build/                     # ビルド中間物・ISO（Git 管理外）
└── rootfs/                    # ルートファイルシステム（Git 管理外）
```

`build/` と `rootfs/` はビルド成果物のため Git 管理対象外です。`iso/COPYING` のみ例外的に追跡されます。

## CI

GitHub Actions で次の検証を自動実行します。

| ワークフロー | トリガー | 内容 |
|--------------|----------|------|
| `.github/workflows/ci.yml` | push / pull request / 手動 | ドキュメント検証、ライセンス検証、`make build-kernel`、`make build-rootfs`、ISO ビルド（参考） |
| `.github/workflows/release.yml` | `v*.*.*` タグ push | CI 実行、ISO とソースバンドルの添付、Release 作成 |

ISO ビルドジョブは、カーネル成果物の配置や Limine の入手がレーン間で未接続のため、現時点では**参考（失敗しても CI 全体は赤にしない）**として実行します。接続が完了した時点で必須ジョブに昇格させます。

ローカルで同じ検証を行う場合:

```bash
make build-kernel
make build-rootfs
test -f iso/COPYING && test -f docs/requirements.md && test -f docs/license.md
```

## トラブルシューティング

| 症状 | 対処 |
|------|------|
| `make: *** No rule to make target 'iso'` | `make iso` は未実装です。`./scripts/build-iso.sh` を直接実行してください |
| kernel の Makefile が `*** missing separator` で落ちる | macOS の `make` 3.81 が原因です。`brew install make` で `gmake` を導入してください |
| カーネルビルドが「コンパイルをスキップ」で終わる | x86_64 Linux 向けクロスコンパイラがありません。Linux ホストまたは Docker 内で実行してください |
| `bc: command not found` / `flex: not found` | カーネルビルド依存が不足しています。`bc`、`bison`、`flex`、`libelf-dev`、`libssl-dev` を導入してください |
| Buildroot のダウンロードに失敗する | ネットワーク制限時は自動的に雛形生成へ切り替わります。ログの `[警告]` を確認してください |
| `ISO 作成ツールが見つかりません` | `xorriso` を導入してください（macOS: `brew install xorriso`） |
| `Limine ブートローダ本体が見つかりません` | `limine-bios.sys` と `limine-efi.sys` を `build/limine/` に配置するか、`LIMINE_DIR` を指定してください |
| `カーネルイメージが見つかりません` | `cp build/linux-6.18.63/arch/x86/boot/bzImage build/kernel` を実行してください |
| `rootfs/bin/sh` が壊れたリンクになる | `busybox` 本体が未配置です。Buildroot のビルド完了後、または `busybox` を `rootfs/bin/` に配置してください |
| ISO から起動してもシェルが出ない | `boot/limine.cfg` の `KERNEL_PATH` / `CMDLINE` と、ステージングされた `boot/kernel` を確認してください |

## 開発への参加

本リポジトリはレーン分割で並行開発しています。

| レーン | 担当領域 | 主な所有ファイル |
|--------|----------|------------------|
| A | ビルドシステム、カーネル、ルートFS | `Makefile`、`scripts/build-kernel.sh`、`scripts/build-rootfs.sh`、`config/buildroot-defconfig`、`config/kernel-defconfig` |
| B | ブート、ISO、QEMU | `boot/`、`scripts/build-iso.sh`、`scripts/run-qemu.sh` |
| C | パッケージ、日本語環境 | `packages/`、`config/packages.txt` |
| D | 追加実装（インストーラ、システム設定など） | 担当領域のファイル |
| E | ドキュメント、CI、リリース、ライセンス遵守 | `README.md`、`docs/`、`.github/workflows/`、`iso/COPYING` |

コントリビュート時の原則:

- 秘密情報（API キー、トークン、証明書）をコミットしない
- 新しい OSS を同梱する場合は `iso/COPYING` と [`docs/license.md`](docs/license.md) を同時に更新する
- `make build-kernel` と `make build-rootfs` が通る状態を保つ

## ライセンス

プロジェクト本体（ビルドスクリプト、設定、ドキュメント）は [MIT License](LICENSE) の下で公開されています。

生成される ISO イメージには、Linux カーネル（GPL-2.0）、BusyBox（GPL-2.0）、OpenRC（BSD-2-Clause）、musl（MIT）、Limine（BSD-2-Clause）などの OSS が含まれます。それぞれの著作権表示とライセンス全文は ISO 内の `/usr/share/licenses/` に収録し、一覧は [`iso/COPYING`](iso/COPYING) に記載しています。

GPL / LGPL 対象コンポーネントについては、対応する完全なソースコードを提供します。取得方法と運用は [`docs/source-flow.md`](docs/source-flow.md) を参照してください。

## ドキュメント

| ドキュメント | 内容 |
|--------------|------|
| [`docs/requirements.md`](docs/requirements.md) | 機能要件、非機能要件、マイルストーン、レーン間インタフェース |
| [`docs/license.md`](docs/license.md) | 同梱 OSS のライセンス一覧、配布時の義務、遵守チェックリスト |
| [`docs/source-flow.md`](docs/source-flow.md) | 配布時のソース提供フロー、マニフェスト運用、リリース手順 |
| [`docs/source-manifest.example.tsv`](docs/source-manifest.example.tsv) | ソースマニフェストのテンプレート |
| [`iso/COPYING`](iso/COPYING) | ISO に同梱される OSS のライセンス一覧と個別ファイルへのポインタ |
