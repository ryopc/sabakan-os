# 配布時のソース提供フロー

- 版: 0.1.0（ドラフト）
- 最終更新: 2026-11-13
- 関連: [`license.md`](license.md)、[`requirements.md`](requirements.md)、[`../iso/COPYING`](../iso/COPYING)

## 1. 目的

SabakanOS の ISO イメージには GPL / LGPL 対象のバイナリが含まれます。本ドキュメントは、配布物に含まれるすべてのバイナリについて「対応ソース」または「取得手段」を揃え、リリースごとに検証・保管する運用を定義します。

目標は次の 1 点です。

> ISO を受け取った第三者が、その ISO に含まれる任意の OSS について、同一のソースから同一のバイナリを再ビルドできる状態を、リリース時点で保証する。

## 2. 原則

1. **バイナリとソースは 1 対 1** — ISO に含まれるバイナリは、すべてマニフェスト上で 1 行を持つ。
2. **バージョンは固定** — タグ・コミットハッシュ・tarball のハッシュのいずれかで特定できる形にする。「最新版」という記載は禁止。
3. **取得手段は 3 種類のいずれか** — 同一媒体への同梱、同一サーバからのダウンロード、Written Offer。
4. **改変は隠さない** — パッチ、設定変更、フォントのサブセット化はすべて記録し、成果物に含める。
5. **記録は 3 年以上保管** — 配布終了後も 3 年間はソースを取得可能な状態に保つ。

## 3. 用語

| 用語 | 定義 |
|------|------|
| 対応ソース | バイナリの生成に使用した完全なソース。ビルドスクリプト、設定、パッチ、生成手順を含む |
| マニフェスト | バイナリとソース・ライセンス・取得先を対応付けた一覧（`docs/source-manifest.tsv`） |
| ソースバンドル | マニフェストに基づき収集したソース一式（`build/source/` とそのアーカイブ） |
| SBOM | 同梱コンポーネントの機械可読な一覧（SPDX または CycloneDX） |
| Written Offer | ソース提供を書面で申し出る文書。GPL-2.0 第 3 条 (b) などで認められる手段 |

## 4. 全体フロー

```text
[1] コンポーネント採用
      │  実装レーンが packages/ に追加
      ▼
[2] ライセンス特定・マニフェスト登録        ← docs/license.md の表を更新
      │
      ▼
[3] ソース取得（バージョン固定・ハッシュ記録）
      │  make source-bundle
      ▼
[4] 改変の記録（パッチ・設定の保存）
      │
      ▼
[5] 整合検証（ISO 内バイナリ ⇔ マニフェスト ⇔ ソース）
      │  CI: source-manifest ジョブ
      ▼
[6] リリース（ISO + ソースバンドル + SBOM を添付）
      │
      ▼
[7] 保管・監査（3 年、ハッシュと取得ログを保持）
```

## 5. マニフェスト仕様

`docs/source-manifest.tsv` はタブ区切りの UTF-8 テキストです。1 行が 1 コンポーネントに対応します。テンプレートは [`source-manifest.example.tsv`](source-manifest.example.tsv) を参照してください。

### 5.1 列定義

| 列 | 必須 | 内容 | 例 |
|----|------|------|-----|
| `component` | 必須 | パッケージ名。`/usr/share/licenses/<component>/` と一致させる | `busybox` |
| `version` | 必須 | 固定バージョン。タグ名またはコミットハッシュ | `1.37.0` |
| `license` | 必須 | SPDX 識別子。複数は `AND` / `OR` で表現 | `GPL-2.0-only` |
| `upstream_url` | 必須 | 上流プロジェクトの URL | `https://busybox.net` |
| `source_url` | 必須 | 対応ソースの取得先 URL（tarball またはリポジトリ） | `https://busybox.net/downloads/busybox-1.37.0.tar.bz2` |
| `sha256` | 必須 | 取得したソースアーカイブの SHA-256。リポジトリ取得の場合は空可 | `4f2c…` |
| `patches` | 任意 | 適用パッチのファイル名（`scripts/patches/` 配下）。複数はカンマ区切り | `0001-jp106-keymap.patch` |
| `in_iso` | 必須 | ISO に同梱されるか（`yes` / `no`）。`no` はビルドホスト専用ツール | `yes` |
| `notes` | 任意 | 補足。ライセンス確認状況など | `辞書データを含む` |

### 5.2 記入例

| component | version | license | source_url | in_iso |
|-----------|---------|---------|------------|--------|
| linux-kernel | 6.18.63 | GPL-2.0-only | kernel.org の該当 tarball | yes |
| busybox | 1.37.0 | GPL-2.0-only | busybox.net の tarball | yes |
| musl | 1.2.x | MIT | musl-libc.org の tarball | yes |
| openrc | 0.5x | BSD-2-Clause | github.com/OpenRC/openrc のタグ | yes |
| apk-tools | 2.14.x | GPL-2.0-only | gitlab.alpinelinux.org/alpine/apk-tools のタグ | yes |
| limine | 8.x | BSD-2-Clause | github.com/limine-bootloader/limine のリリース | yes |
| buildroot | 2026.08.1 | GPL-2.0-or-later | buildroot.org の tarball | no |
| xorriso | 1.5.x | GPL-3.0-or-later | gnu.org の tarball | no |

> 実際の値はリリースごとに確定させます。`in_iso=no` のツール（ビルドホスト専用）は、ISO に含まれないためソース提供義務は発生しませんが、再現性のためマニフェストには残します。

## 6. ソース収集手順

### 6.1 バージョンの固定

1. 上流のリリースタグまたはコミットハッシュを確定し、`version` に記録する
2. tarball を取得し、`sha256sum` を `sha256` に記録する
3. OpenPGP 署名が公開されている場合は署名検証を行う

```bash
# 入手と検証の例
curl -LO https://busybox.net/downloads/busybox-1.37.0.tar.bz2
sha256sum busybox-1.37.0.tar.bz2
# 署名がある場合
gpg --verify busybox-1.37.0.tar.bz2.sig busybox-1.37.0.tar.bz2
```

### 6.2 改変の記録

- カーネル設定（`.config`）、ビルド変数、`defconfig` の変更は `config/` に置き、そのままソースバンドルへ含める
- パッチは `scripts/patches/<component>/` に置き、`patches` 列に列挙する
- パッチには適用順が分かる連番を付け、必要なら `series` ファイルを併置する
- フォントのサブセット化を行った場合は、生成スクリプトと元フォントを両方含める

### 6.3 ソースバンドルの生成

```bash
make source-bundle
```

期待される動作:

1. マニフェストを読み、`in_iso=yes` のコンポーネントについてソースを取得またはコピーする
2. `sha256` を検証し、不一致なら失敗する
3. `build/source/` に `<component>-<version>/` として展開する
4. `build/source/MANIFEST.tsv`、`build/source/SBOM.json`、`build/source/README.txt` を生成する
5. `build/source/sabakanos-<version>-source.tar.zst` にまとめる

> **現状**: `make source-bundle` は未実装です（[`requirements.md`](requirements.md) 第 6 章）。それまでの暫定措置として、`.github/workflows/release.yml` はリポジトリ本体を `sabakanos-<version>-source.tar.zst` として添付し、警告を出力します。ただし**リポジトリ本体のアーカイブだけでは、同梱 OSS（カーネル、BusyBox、musl、Limine など）の対応ソース提供義務を満たしません**。リリースを対外公開する前に、本節の手順でソースバンドルを用意してください。

`make source-bundle` が未実装の段階では、同等の処理を手作業で行い、同じディレクトリ構成に揃えてください。

### 6.4 ソースバンドルの構成

```text
build/source/
├── MANIFEST.tsv              # 確定版マニフェスト
├── SBOM.json                 # SPDX または CycloneDX
├── README.txt                # 取得方法・ビルド方法の要約
├── linux-kernel-6.12.x/
│   ├── linux-6.12.x.tar.xz
│   ├── config/kernel.config
│   └── patches/
├── busybox-1.37.0/
│   ├── busybox-1.37.0.tar.bz2
│   └── .config
└── ...
```

`README.txt` には次を記載します。

- SabakanOS のバージョンと対応する Git タグ
- ソースの取得元と検証方法（SHA-256 一覧）
- ビルド手順（`make build-kernel` 等）とツールチェーンのバージョン
- 問い合わせ先

## 7. 配布方法

優先順位は上から順です。

### 7.1 同一サーバからのダウンロード（原則）

GitHub Release に ISO とソースバンドルを同時に添付します。ISO のダウンロードページと同一のリリースページから取得できるため、GPL-2.0 第 3 条 (a) の要件を満たします。

```text
https://github.com/ryotagtagtag-wq/sabakan-os/releases/tag/v<version>
├── sabakanos-<version>-x86_64.iso
├── sabakanos-<version>-x86_64.iso.sha256
├── sabakanos-<version>-source.tar.zst
└── SBOM.json
```

### 7.2 同一媒体への同梱

ソースサイズが小さく ISO に収まる場合は、別ボリュームまたは追加ファイルとして同梱できます。ISO サイズの目標（[`requirements.md`](requirements.md) NFR-003）に影響するため、原則として 7.1 を使います。

### 7.3 Written Offer

上記が困難な場合（オフライン配布、第三者への再配布など）に限り、書面による申し出を発行します。有効期間は配布日から 3 年間です。

```text
Written Offer for Source Code

SabakanOS <version>（配布日: <YYYY-MM-DD>）に含まれる GPL / LGPL 対象ソフトウェアについて、
第三者に対応ソースコードの完全なコピーを提供します。

対象: <iso/COPYING に記載のコンポーネント一覧>
提供方法: 電子ダウンロード（URL を通知）または物理媒体
申し出の有効期間: 配布日から 3 年間
連絡先: <プロジェクトの連絡先>

本申し出は、GPL-2.0 第 3 条 (b)、GPL-3.0 第 6 条 (b)、
LGPL-2.1 第 4 条等に基づくものです。
```

発行した Written Offer は、配布ログとともに 3 年間保管します。

## 8. リリース手順

1. `main` の CI が green であることを確認する
2. マニフェストを確定する（`docs/source-manifest.tsv` を更新）
3. `iso/COPYING` を更新し、ISO 内 `/usr/share/licenses/` と突合する
4. `make source-bundle` を実行し、ハッシュ検証が通ることを確認する
5. ISO をビルドし、`sha256sum` を記録する
6. SBOM を生成する
7. タグを push し、`.github/workflows/release.yml` で Release を作成する
8. Release に ISO、ISO のハッシュ、ソースバンドル、SBOM が添付されていることを確認する
9. [`license.md`](license.md) のリリース前チェックリストを実行し、結果を記録する
10. 保管場所（Release とバックアップ）に成果物を保存する

## 9. 検証（CI）

`.github/workflows/ci.yml` の `license` ジョブで次を検証します。

| 検証項目 | 失敗条件 |
|----------|----------|
| 必須ファイルの存在 | `iso/COPYING`、`docs/license.md`、`docs/source-flow.md` のいずれかが無い |
| `iso/COPYING` の内容 | コンポーネント一覧の見出しが無い、または空 |
| マニフェストの書式 | ヘッダ列が仕様と一致しない |
| 禁止パターン | 秘密情報らしき文字列（`BEGIN PRIVATE KEY` 等）を検出 |

`make source-bundle` が実装された後は、ハッシュ検証と SBOM 生成も同じジョブに追加します。

## 10. 保管と監査

| 対象 | 保管期間 | 保管場所 |
|------|----------|----------|
| ISO とハッシュ | 3 年以上 | GitHub Release（削除しない）＋ローカルバックアップ |
| ソースバンドル | 3 年以上 | 同上 |
| SBOM | 3 年以上 | 同上 |
| リリース時チェックリストの記録 | 3 年以上 | `docs/releases/<version>.md`（将来追加） |
| Written Offer の発行記録 | 3 年以上 | リリース記録に併記 |

監査時は「ISO 内のバイナリ → `iso/COPYING` → マニフェスト → ソースバンドル」の順に辿り、各段階で一致することを確認します。

## 11. 障害時の対応

| 状況 | 対応 |
|------|------|
| 上流のソースが削除された | 保管済みのソースバンドルを提供する。再配布が許諾されている場合はミラーを公開する |
| ハッシュが一致しない | リリースを止める。取得元の改変・侵害を疑い、別ミラーから再取得して照合する |
| ライセンスが途中で変更された | 該当バージョンの条項を確認し、必要ならバージョンを固定し直す。`license.md` を更新する |
| 同梱物のライセンスが不明と判明した | 該当コンポーネントを ISO から外すか、許諾を確認できるまでリリースを停止する |
| 誤って秘密情報を含めて配布した | 直ちに該当する鍵を失効させ、リリースを撤回し、影響範囲を記録する |

## 12. 自動化の拡張案

将来的に以下を CI に追加します。

- `packages/` のマニフェストから `docs/source-manifest.tsv` の未登録項目を検出
- ISO 内の ELF ファイルを列挙し、マニフェストとの差分を検出
- SPDX 形式の SBOM を `cyclonedx` / `syft` で自動生成
- ソースバンドルの再ビルドによるハッシュ一致検証（再現性チェック）
