# SabakanOS ブートパイプライン修正プラン

## ゴール
`make build-kernel` / `make build-rootfs` / `make iso` / `make test` が連携し、QEMU でシェルに到達するブート可能 ISO (`build/sabakanos.iso`) を生成する。現状の「ゼロ埋めカーネル・dangling symlink の `/bin/sh`・initramfs なし」によるブート不能（FR-004 未達）を解消する。

## 前提・制約
- plan エージェントはファイル編集・ミューティングコマンドを実行しない。本プランは実装エージェントに引き継ぐ。
- リポジトリレーン分担（A: build/kernel/rootfs, B: boot/ISO/QEMU, E: docs/CI）を尊重し、レーン所有ファイルのみ担当レーンが編集する。
- macOS ホストでも `make build-kernel` が `exit 1` にならない（ユーザ決定：macOS でも何らかのカーネル出力を出す）。
- 実際のブート可能カーネルは Linux 環境（GitHub Actions ubuntu-24.04 / Docker）でビルド。macOS は Docker 経由ビルド、または非ブート可能プレースホルダ出力＋WARN。

## 設計決定
1. **macOS カーネル出力**: `scripts/build-kernel.sh` の Linux-only 硬止めを撤廃。macOS では `docker` があれば `Dockerfile.build` コンテナ内で Linux カーネルをビルドしホストの `build/` に出力。`docker` なしでは `.config` 生成まで行い、空でないプレースホルダ `bzImage` を出力＋WARN（非ブート可能、Linux で再ビルド要）。
2. **initramfs は必須化**: `build-rootfs.sh` が `build/initramfs.img`（cpio アーカイブ化 rootfs）を出力し、`build-iso.sh` は欠落時はエラー（`die`）にする。`limine.cfg` の `initrd_path` と整合。
3. **`/bin/sh` dangling 解消**: `rootfs/bin` に `busybox` 実体を配置。`bin/sh -> busybox` が解決することを確認。
4. **CI はカーネル・ISO 失敗を致命に**: `ci.yml` の `build_kernel`/`build_iso` の `continue-on-error` を解除、または `ci-summary` で致命判定対象に加える。
5. **arm64 EFI は `BOOTAA64.EFI`**: `build-iso.sh` の EFI ファイル名を arm64 対応に分岐。
6. **`make all/iso/test` を実装**: Makefile のスタブを実体化（FR-003, FR-004）。
7. **ブート検証を追加**: `run-qemu.sh` でシリアル出力から「SabakanOS 起動完了」/シェルプロンプトを検出し、未到達なら非ゼロ終了。CI でブートテストジョブを追加。

## 実装タスク（順序）

### レーン A（Makefile, scripts/build-*.sh, config/）
1. `scripts/build-kernel.sh` 修正
   - `uname -s != Linux` の `exit 1` 撤廃
   - Linux 分岐：既存フロー維持（実 `bzImage` 出力）
   - macOS 分岐：`docker` 存在確認 → `Dockerfile.build` ベースコンテナで `build-kernel.sh` を実行しホストの `build/` に出力。`docker` なし → `.config` 生成＋非ゼロプレースホルダ `bzImage` 出力＋WARN
   - ARM64 クロスコンパイル分岐は維持
2. `scripts/build-rootfs.sh` 修正
   - `set -u` → `set -eu`
   - `busybox` 実体を `rootfs/bin/busybox` に配置（ビルド or 事前ステージ）。`bin/sh -> busybox` が解決することを確認
   - `rootfs/` を `build/initramfs.img`（`find . | cpio -o -H newc | gzip`）にアーカイブして出力
3. `scripts/build-iso.sh` 修正
   - `resolve_kernel_and_initramfs`: initramfs 欠落時は `warn` ではなく `die`（必須化）
   - arm64 EFI: `BOOTX64.EFI` → `BOOTAA64.EFI` に分岐（`LIMINE_EFI` / UEFI CD も arm64 対応）
   - コメント typo `LIMAINE_DIR` → `LIMINE_DIR`
4. `scripts/run-qemu.sh` 修正
   - QEMU 終了後、シリアル出力（`-serial stdio` のキャプチャ）から「SabakanOS 起動完了」またはシェルプロンプトを検出。未到達 → `die`（非ゼロ終了）
   - タイムアウト付き実行（`timeout` コマンド使用）
5. `config/kernel-defconfig-common` 確認
   - `CONFIG_NET=n` は FR-032（ネットワーク）と矛盾。M0 ではコメントアウト説明を追加し、M1 で `CONFIG_NET=y` + 最小ドライバを有効化（本プランでは注記のみ、実装は M1 へ回す）
6. `Makefile` 修正
   - `all`: `build-kernel` + `build-rootfs` を順次実行（現状 `help` エイリアス）
   - `iso`: `scripts/build-iso.sh` 呼び出し（現状未実装記述）
   - `test`: `scripts/run-qemu.sh` 呼び出し（現状未実装記述）
   - `install`/`source-bundle`: stub 維持。`source-bundle` は参照する `collect-sources.sh`/`generate-sbom.sh` が不在のため stub スクリプト追加 or Makefile からの参照削除

### レーン B（boot/）
7. `boot/limine.cfg` 確認
   - `initrd_path: boot():/boot/initramfs.img` が `build-iso.sh` のステージング出力と整合していること（現状整合。initramfs 生成後に再確認）

### レーン E（.github/workflows/, docs/）
8. `.github/workflows/ci.yml` 修正
   - `build_kernel` / `build_iso` の `continue-on-error: true` → `false`
   - `ci-summary` の致命判定に `build_kernel` / `build_iso` を追加
   - ブートテストジョブ追加（`qemu-system-x86_64` で ISO 起動、シリアル出力から起動完了を検出；arm64 は `qemu-system-aarch64` + OVMF でオプション）
9. `.github/workflows/release.yml` 軽微修正
   - arm64 ISO ディレクトリ作成が二重（56行・63行重複）→ 重複削除

### テスト
10. テストスイート導入（`tests/` ディレクトリ、bats または純 POSIX sh）
    - `rootfs/bin/sh` が busybox を解決する
    - `rootfs/init` / `etc/passwd` / `etc/hostname` 存在
    - `build/initramfs.img` 生成・非空
    - `build/sabakanos.iso` 生成・非空（CI/Linux のみ）
    - QEMU ブートでシェル到達（CI のみ）

## 検証手順（実装後）
1. macOS で `make build-kernel` → `exit 0`、`.config` 生成、プレースホルダ or 実 `bzImage` 出力
2. Linux（CI ローカル再現 or Docker）で `make build-kernel` → 実 `bzImage` 出力
3. `make build-rootfs` → `rootfs/bin/busybox` 実体存在、`build/initramfs.img` 非空
4. `make iso` → `build/sabakanos.iso` 非空、中身に実カーネル+initramfs
5. `make test` → QEMU シリアル出力に「SabakanOS 起動完了」出現、終了コード 0
6. CI ワークフローが green（`build_kernel`, `build_rootfs`, `build_iso`, boot test ともに success）

## 見送り / out-of-scope（本プランでは実施しない）
- 日本語デスクトップ（mozc/ibus/noto-cjk/Openbox）の rootfs 同梱（FR-023/024 は M2 へ）
- `sabakan-install` インストーラ実装（FR-014 は M4 へ）
- `CONFIG_NET=y` への変更とネットワークドライバ追加（M1 へ回し、本プランでは注記のみ）
- arm64 実機サポート（要件定義で対象外）
- `make install` / `make source-bundle` の本格実装（stub 維持）

## 未解決の判断事項
- macOS で `docker` が未インストールの場合、プレースホルダ `bzImage` の中身をどう構成するか（空でないダミーブートセクタ vs 最小 stub）。推奨: Linux ブートヘッダのマジック番号のみ模した最小 stub を出力し WARN で非ブート可能を明示。
- テストフレームワークを bats にするか純 POSIX sh にするか。推奨: 依存を増やさない純 POSIX sh（CI は ubuntu で bats インストールも可）。
