# ライセンス遵守方針

- 版: 0.1.0（ドラフト）
- 最終更新: 2026-11-13
- 適用範囲: SabakanOS のリポジトリ、ビルド成果物、配布する ISO イメージおよびソースバンドル

## 1. 目的

SabakanOS は多数の OSS を組み合わせて構成されます。本ドキュメントは、同梱物のライセンスを把握し、配布時に求められる義務を確実に果たすための方針を定めます。

対象読者は次のとおりです。

- パッケージやコンポーネントを追加する実装担当者
- リリース作業を行う担当者
- 配布物のライセンス確認を行うレビュアー

## 2. 基本方針

1. **同梱物はすべて記録する** — バイナリを 1 つ追加したら、`iso/COPYING` と本ドキュメントの一覧、およびソースマニフェストを同時に更新する。
2. **ライセンス全文を同梱する** — ISO 内 `/usr/share/licenses/<component>/` に各ライセンス全文を配置する。
3. **対応ソースを用意する** — GPL / LGPL 対象物は、配布と同時に完全な対応ソースを取得できる状態にする（[`source-flow.md`](source-flow.md)）。
4. **追加条件を課さない** — GPL 対象物の再配布に独自の制限や追加条項を付けない。
5. **不明なものは載せない** — ライセンスが特定できない、または再配布が許諾されないコンポーネントは同梱しない。

### 2.1 GPLv3 の扱い

本方針では GPLv3 の採用を禁止しませんが、`config/packages.txt` の方針に従い、基本ユーティリティは BusyBox（GPL-2.0）のアプレットで賄うことを優先します。GNU 版の `bash`、`grep`、`gzip`、`tar` などを導入する場合は、GPLv3 の義務（インストール情報の提供など）が発生するため、同梱判断を記録してください。

## 3. ライセンス構成

| 対象 | ライセンス | 全文 |
|------|-----------|------|
| プロジェクト本体（ビルドスクリプト、設定、ドキュメント） | MIT | [`../LICENSE`](../LICENSE) |
| 同梱 OSS | 各コンポーネントのライセンス | ISO 内 `/usr/share/licenses/`、一覧は [`../iso/COPYING`](../iso/COPYING) |

プロジェクト本体が MIT であることは、同梱 OSS のライセンスを MIT に変更するものではありません。ISO イメージ全体は複数ライセンスの集合体として配布されます。

## 4. 同梱コンポーネント一覧

一覧は `config/packages.txt`（ベースパッケージ）と `config/buildroot-defconfig`（ルートFS構成）に基づきます。バージョンは再現性のためビルド時に固定し、確定値はソースマニフェストを正とします。

「状態」列の意味は次のとおりです。

- **同梱**: ISO に含める
- **任意**: 既定では含めない。利用者が導入する
- **追加予定**: 要件は定義済みだが未同梱。同梱時に本表と `iso/COPYING` を更新する

### 4.1 コアシステム

| コンポーネント | 状態 | ライセンス | 配布時の義務 | ソース取得先 |
|----------------|------|------------|--------------|--------------|
| Linux kernel 6.18.63 | 同梱 | GPL-2.0-only | ライセンス全文の同梱、対応ソースの提供、変更点（`config/kernel-defconfig`）の開示 | kernel.org |
| BusyBox | 同梱 | GPL-2.0-only | 対応ソースの提供（ビルド時 `.config` を含む） | busybox.net |
| musl libc | 同梱 | MIT | 著作権表示とライセンス全文の同梱 | musl-libc.org |
| OpenRC | 同梱 | BSD-2-Clause | 著作権表示とライセンス全文の同梱 | github.com/OpenRC/openrc |
| apk-tools | 同梱 | GPL-2.0-only | 対応ソースの提供 | gitlab.alpinelinux.org/alpine/apk-tools |
| alpine-baselayout | 同梱 | GPL-2.0-only | 対応ソースの提供、設定ファイルの変更点の開示 | gitlab.alpinelinux.org/alpine/aports |
| Buildroot（ビルドツール） | 非配布 | GPL-2.0-or-later | ISO に含まれないため義務なし（ビルドホスト専用） | buildroot.org |

> **Buildroot の扱い**: Buildroot 自体は配布物に含まれませんが、生成されたルートFSには Buildroot がビルドした BusyBox・musl などが含まれます。個々のコンポーネントについて本条項を適用してください。

### 4.2 ブートローダーと起動

| コンポーネント | 状態 | ライセンス | 配布時の義務 | ソース取得先 |
|----------------|------|------------|--------------|--------------|
| Limine | 同梱 | BSD-2-Clause | 著作権表示とライセンス全文の同梱 | github.com/limine-bootloader/limine |
| xorriso / libisoburn | 非配布 | GPL-3.0-or-later | ISO に含まれないため義務なし（ビルドホスト専用） | gnu.org/software/xorriso |
| mtools | 非配布 | GPL-3.0-or-later | 同上 | gnu.org/software/mtools |
| dosfstools | 非配布 | GPL-3.0-or-later | 同上 | github.com/dosfstools/dosfstools |

> Limine の本体（`limine-bios.sys`、`limine-efi.sys`）は現在 `build/limine/` に手動配置しています。ISO に同梱されるため、**リリース時には Limine のライセンス全文と著作権表示を `/usr/share/licenses/limine/` に配置する必要があります**。

### 4.3 ネットワーク

| コンポーネント | 状態 | ライセンス | 配布時の義務 | ソース取得先 |
|----------------|------|------------|--------------|--------------|
| dhcpcd | 同梱 | BSD-2-Clause | 著作権表示とライセンス全文の同梱 | github.com/NetworkConfiguration/dhcpcd |
| wpa_supplicant | 同梱 | BSD-3-Clause | 著作権表示とライセンス全文の同梱 | w1.fi |
| wireless-tools | 同梱 | GPL-2.0-only | 対応ソースの提供 | hpl.hp.com/personal/Jean_Tourrilhes/Linux/Tools.html |
| iptables | 同梱 | GPL-2.0-only | 対応ソースの提供 | netfilter.org |
| iproute2 | 同梱 | GPL-2.0-or-later | 対応ソースの提供 | kernel.org（iproute2） |
| OpenSSH（クライアント／サーバー） | 同梱 | SSH 独自（BSD 系） | 著作権表示とライセンス全文の同梱 | openssh.com |
| dropbear | 任意 | MIT | 著作権表示とライセンス全文の同梱 | matt.ucc.asn.au/dropbear |

### 4.4 システム管理とユーティリティ

| コンポーネント | 状態 | ライセンス | 配布時の義務 | ソース取得先 |
|----------------|------|------------|--------------|--------------|
| sudo | 同梱 | ISC | 著作権表示とライセンス全文の同梱 | sudo.ws |
| procps-ng | 同梱 | GPL-2.0-or-later / LGPL-2.1-or-later | 対応ソースの提供 | gitlab.com/procps-ng/procps |
| cronie | 同梱 | MIT および BSD | 著作権表示とライセンス全文の同梱 | github.com/cronie-crond/cronie |
| less | 同梱 | GPL-3.0-or-later または BSD-2-Clause（デュアル） | 選択したライセンスの全文同梱。GPLv3 を選ぶ場合は対応ソース提供 | gnu.org/software/less |
| vi / vim | 同梱 | BusyBox アプレットは GPL-2.0-only、vim は Vim license | 実体に応じた全文同梱と対応ソース提供 | busybox.net / vim.org |
| grep / gzip / tar | 同梱 | BusyBox アプレットは GPL-2.0-only、GNU 版は GPL-3.0-or-later | 実体に応じた対応ソース提供 | busybox.net / gnu.org |
| syslog（busybox syslogd） | 同梱 | GPL-2.0-only | 対応ソースの提供 | busybox.net |
| bash | 任意 | GPL-3.0-or-later | 対応ソースの提供、インストール情報の提供 | gnu.org/software/bash |
| ロケール／キーボード定義 | 同梱 | musl-locales（MIT）、Alpine の kbd 定義（GPL-2.0 系） | 出所とライセンスの明記、全文同梱 | musl-libc.org / aports |

> `grep`、`gzip`、`tar`、`vi` は BusyBox のアプレットとして提供される限り BusyBox の GPL-2.0 に含まれます。GNU 版を別途導入した場合は、それぞれのライセンスが追加されます。

### 4.5 日本語環境（追加予定）

日本語環境は要件（FR-020〜FR-024）として定義済みですが、現時点では ISO に同梱されていません。同梱を決定した時点で「状態」を **同梱** に変更し、ライセンス全文を配置してください。

| コンポーネント | 状態 | ライセンス | 配布時の義務 | ソース取得先 |
|----------------|------|------------|--------------|--------------|
| Mozc | 追加予定 | BSD-3-Clause | 著作権表示・ライセンス全文の同梱 | github.com/google/mozc |
| Mozc 辞書データ | 追加予定 | Mozc と同じ（BSD-3-Clause） | 同上。外部辞書を混ぜる場合は出所とライセンスを追記 | github.com/google/mozc |
| IBus | 追加予定 | LGPL-2.1-or-later | ライセンス全文の同梱、対応ソースの提供 | github.com/ibus/ibus |
| Fcitx5 | 追加予定 | LGPL-2.1-or-later | 同上 | github.com/fcitx/fcitx5 |
| Noto Sans CJK JP / Noto Serif CJK JP | 追加予定 | SIL OFL 1.1 | ライセンス全文の同梱、改変時は Reserved Font Name の扱いに従う | github.com/notofonts/noto-cjk |
| IPAex フォント | 追加予定 | IPA Font License 1.0 | ライセンス全文の同梱、改変・再配布条件の遵守 | ipa.go.jp/font |

> **フォントの注意**: SIL OFL 1.1 は改変・再配布を認めますが、改変版に元の Reserved Font Name を使用できません。サブセット化や合成を行う場合はフォント名を変更し、変更内容を記録してください。

### 4.6 追加時の手続き

新しいパッケージを `config/packages.txt` に追加する場合、次の 3 点を同時に行います。

1. 本ドキュメントの該当表に行を追加する（ライセンス、義務、ソース取得先）
2. [`../iso/COPYING`](../iso/COPYING) に同じ内容を反映する
3. `docs/source-manifest.tsv` にソースの取得先とハッシュを記録する（[`source-flow.md`](source-flow.md) 5 節）

## 5. 配布時の義務

### 5.1 GPL-2.0（Linux kernel、BusyBox、apk-tools、iptables など）

- バイナリを配布する場合、対応する完全なソースコードを提供する
- ソースにはビルドに必要な設定（`.config`、`kernel-defconfig`、`buildroot-defconfig`、パッチ）を含める
- ライセンス全文と著作権表示を同梱する
- 再配布に追加の制限を課さない
- ソース提供は「バイナリと同時」「書面による申し出（Written Offer）」「同一サーバ経由」のいずれかで行う

### 5.2 GPL-3.0（GNU 版 grep / gzip / tar / bash、xorriso など）

- GPL-2.0 の義務に加え、インストール情報（Installation Information）の提供が必要になる場合がある
- ユーザー製品として配布する場合は、改変版の導入を妨げない手段を提供する
- 追加の特許制限を課さない
- ビルドホスト専用ツール（xorriso など）は ISO に含めなければ義務は発生しない

### 5.3 LGPL-2.1-or-later（IBus、Fcitx5、procps のライブラリなど）

- ライセンス全文と著作権表示を同梱する
- 動的リンクの場合は対応ソースの提供が必要
- 静的リンクまたは改変を行う場合は、再リンク可能な形態でオブジェクトファイル等を提供する
- 改変した LGPL 部分は、その旨と変更内容を明示する

### 5.4 SIL OFL 1.1（Noto CJK など）

- ライセンス全文を同梱する
- フォント単体での販売は行わない
- 改変版を配布する場合は Reserved Font Name を使用せず、名称を変更する
- 他のソフトウェアに埋め込む場合は、フォント単体の抽出・再配布を制限しない

### 5.5 MIT / BSD-2 / BSD-3 / ISC

- 著作権表示とライセンス全文を同梱する
- BSD-3-Clause は、著作権者名を宣伝目的で使用しない条件を含む

### 5.6 独自ライセンス（OpenSSH、Vim、IPA Font License）

- 各ライセンス全文を同梱し、条文の追加条件（名称使用の制限、変更版の扱い等）に従う
- 判断に迷う場合は同梱を見送り、レビューを依頼する

## 6. ISO 内のライセンス配置

```text
/COPYING                                  # iso/COPYING の内容（一覧とポインタ）
/usr/share/licenses/
├── linux-kernel/COPYING
├── busybox/COPYING
├── musl/COPYING
├── openrc/COPYING
├── apk-tools/COPYING
├── limine/COPYING
├── openssh/LICENCE
└── <component>/...
```

規則:

- ディレクトリ名は `config/packages.txt` のパッケージ名と一致させる
- ライセンス全文は改変せずに配置する
- 複数ライセンスのコンポーネントは `COPYING`、`LICENSE`、`LICENCE`、`LICENSE.*` をすべて配置する
- `/COPYING` は同梱物の一覧と各ディレクトリへのポインタを兼ねる

## 7. ソース提供の手段

| 手段 | 適用場面 | 実装 |
|------|----------|------|
| 同一媒体への同梱 | ソースサイズが小さく、ISO に収まる場合 | `make source-bundle` の成果物を ISO または別ボリュームに含める |
| 同一サーバからのダウンロード | GitHub Release にソースバンドルを添付する場合（原則） | リリースごとにタグと対応関係を明示 |
| 書面による申し出（Written Offer） | 上記が難しい場合の最終手段 | 申し出文面と有効期間（3 年）を `docs/source-flow.md` に従って発行 |

詳細な運用手順、マニフェストの書式、リリース前チェックリストは [`source-flow.md`](source-flow.md) を参照してください。

## 8. 変更を加えた場合の扱い

- カーネル設定変更、パッチ適用、フォントのサブセット化など、 upstream にない変更を行った場合は、パッチ本体と適用方法をソースバンドルに含める
- 変更内容は `docs/source-flow.md` のマニフェスト `patches` 列に記録する
- ルートFSへ直接配置する設定ファイル（`rootfs/etc/...`）は、生成スクリプトごとソースバンドルに含める
- GPL-3.0 対象物の変更は、変更日と変更内容をファイル内に表示する
- ライセンス表示を削除・改変しない

## 9. 禁止事項と注意点

| 事項 | 理由 |
|------|------|
| ライセンス不明のバイナリを同梱する | 再配布許諾が確認できず、違反リスクがある |
| GPL-2.0-only のコードと GPL-3.0-only のコードを同一バイナリに混在させる | ライセンス非互換（Linux カーネルと GPL-3.0 のみのコードなど） |
| GPL 対象物に追加の利用制限や EULA を課す | GPL 第 6 条等に反する |
| ライセンス全文を省略してポインタのみ置く | 配布時の同梱義務を満たさない |
| フォントの改変版に元の Reserved Font Name を使う | OFL 1.1 の条件違反 |
| Limine の著作権表示を削除する | BSD-2-Clause の表示義務違反 |
| 秘密情報（鍵、トークン）をリポジトリや ISO に含める | セキュリティ事故。`.gitignore` と CI で防止する |
| 出所の不明なファームウェアを再配布する | ファームウェアは個別条項が多く、確認が必須 |

## 10. リリース前チェックリスト

リリース担当者は次をすべて確認します。1 つでも未確認ならリリースを止めます。

- [ ] ISO に含まれる全バイナリが本ドキュメントの一覧に存在する
- [ ] 一覧の各行にライセンスとソース取得先が記載されている
- [ ] `iso/COPYING` が最新の一覧と一致している
- [ ] `/usr/share/licenses/` に各ライセンス全文が配置されている（Limine を含む）
- [ ] ソースマニフェストの `sha256` が実際のソースと一致する
- [ ] ソースバンドルが Release に添付されている、または Written Offer を発行済みである
- [ ] カーネル設定（`config/kernel-defconfig`）と Buildroot defconfig がソースバンドルに含まれている
- [ ] パッチ適用コンポーネントのパッチがソースバンドルに含まれている
- [ ] Reserved Font Name の扱いに違反がない
- [ ] 秘密情報の混入がない（`git grep` および CI のシークレットスキャン）
- [ ] リリースノートにライセンス変更点が記載されている

## 11. 役割

| 役割 | 担当 | 責任 |
|------|------|------|
| コンポーネント追加 | 実装レーン | ライセンスの特定、本表とマニフェストの更新、ライセンス全文の配置 |
| ドキュメント・CI・リリース・ライセンス遵守 | レーン E | 方針の維持、チェックリストの実行、`iso/COPYING` の整合、リリース承認前の確認 |
| 最終承認 | プロジェクトオーナー | 法務判断が必要な案件の決定 |

## 12. 改訂履歴

| 版 | 日付 | 変更内容 |
|----|------|----------|
| 0.1.0 | 2026-11-13 | 初版作成（コンポーネント一覧、義務、チェックリスト） |
