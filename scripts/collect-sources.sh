#!/bin/sh
# SabakanOS レーンG1 — ソース収集スクリプト
# 所有: レーンG1 (ライセンスコンプライアンス: ソース収集・SBOM生成)
# 用途: config/packages.txt に記載された GPL/LGPL 対象パッケージの
#       ソースアーカイブを公式リリースURLから取得し、SHA256 を検証・記録する。
#
# 出力:
#   build/sources/<package>/          収集・展開済みソース
#   build/sources/config/             ビルド設定ファイルのコピー
#   build/source-manifest.json        収集結果マニフェスト (JSON)
#
# 他レーン所有ファイル (Makefile, boot/, rootfs/, README.md, docs/, .github/ 等)
# には一切触れない。

set -u

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGES_FILE="$PROJECT_ROOT/config/packages.txt"
SOURCES_DIR="$PROJECT_ROOT/build/sources"
CONFIG_DIR="$PROJECT_ROOT/config"
PATCHES_DIR="$PROJECT_ROOT/patches"
MANIFEST_FILE="$PROJECT_ROOT/build/source-manifest.json"

log() { printf '[collect-sources] %s\n' "$*"; }
warn() { printf '[collect-sources] WARN: %s\n' "$*" >&2; }
err() { printf '[collect-sources] ERROR: %s\n' "$*" >&2; }

# ハッシュコマンドの解決 (sha256sum / shasum -a 256)
hash_cmd=""
if command -v sha256sum >/dev/null 2>&1; then
    hash_cmd="sha256sum"
elif command -v /sbin/sha256sum >/dev/null 2>&1; then
    hash_cmd="/sbin/sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    hash_cmd="shasum -a 256"
fi
if [ -z "$hash_cmd" ]; then
    err "sha256sum / shasum が見つかりません"
    exit 1
fi

hash_file() {
    # $1: ファイルパス -> 標準出力に 64桁の SHA256 を出力
    case "$hash_cmd" in
        shasum\ *) $hash_cmd "$1" | awk '{print $1}' ;;
        *)         $hash_cmd "$1" | awk '{print $1}' ;;
    esac
}

# GPL/LGPL 対象パッケージテーブル
# 書式: パッケージ名|バージョン|ライセンス識別子|ソースアーカイブURL|アーカイブファイル名
# バージョンは固定し、タグ / コミットハッシュ / tarball で特定できる形とする。
PKG_TABLE='
linux-kernel|6.12.34|GPL-2.0-only|https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.34.tar.xz|linux-6.12.34.tar.xz
busybox|1.37.0|GPL-2.0-only|https://busybox.net/downloads/busybox-1.37.0.tar.bz2|busybox-1.37.0.tar.bz2
apk-tools|2.14.3|GPL-2.0-only|https://gitlab.alpinelinux.org/alpine/apk-tools/-/archive/v2.14.3/apk-tools-v2.14.3.tar.gz|apk-tools-v2.14.3.tar.gz
alpine-baselayout|3.7.2|GPL-2.0-only|https://gitlab.alpinelinux.org/alpine/aports/-/archive/master/aports-master.tar.gz|aports-master.tar.gz
iptables|1.8.7|GPL-2.0-only|https://www.netfilter.org/pub/iptables/iptables-1.8.7.tar.bz2|iptables-1.8.7.tar.bz2
iproute2|5.15.0|GPL-2.0-or-later|https://github.com/shemminger/iproute2/archive/refs/tags/v5.15.0.tar.gz|iproute2-5.15.0.tar.gz
'

# packages.txt からパッケージ名を抽出 (コメント行・空行・インラインコメント除去)
read_package_names() {
    if [ ! -f "$PACKAGES_FILE" ]; then
        err "packages.txt が見つかりません: $PACKAGES_FILE"
        return 1
    fi
    grep -vE '^[[:space:]]*#' "$PACKAGES_FILE" \
        | grep -vE '^[[:space:]]*$' \
        | awk '{print $1}'
}

# テーブルから指定パッケージの行を抽出 (name|version|license|url|file)
pkg_lookup() {
    local name="$1"
    printf '%s\n' "$PKG_TABLE" \
        | grep -vE '^[[:space:]]*$' \
        | while IFS='|' read -r n v lic url file; do
            [ "$n" = "$name" ] && printf '%s|%s|%s|%s|%s\n' "$n" "$v" "$lic" "$url" "$file"
        done
}

# 収集対象リストを構築 (packages.txt に登場する GPL/LGPL パッケージ + linux-kernel)
build_targets() {
    local pkg_names n v lic url file
    pkg_names="$(read_package_names || true)"

    while IFS='|' read -r n v lic url file; do
        [ -z "$n" ] && continue
        # packages.txt に登場する GPL/LGPL パッケージ、または linux-kernel を収集対象とする
        if printf '%s\n' "$pkg_names" | grep -qxF -- "$n" || [ "$n" = "linux-kernel" ]; then
            printf '%s|%s|%s|%s|%s\n' "$n" "$v" "$lic" "$url" "$file"
        fi
    done <<< "$(printf '%s\n' "$PKG_TABLE" | grep -vE '^[[:space:]]*$')"
}

# ディレクトリ準備
mkdir -p "$SOURCES_DIR/config"

TMP_MANIFEST="$(mktemp)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

log "収集対象の解析を開始 (packages.txt: $PACKAGES_FILE)"

while IFS='|' read -r name version license url archive; do
    [ -z "$name" ] && continue

    pkg_dir="$SOURCES_DIR/$name"
    archive_path="$pkg_dir/$archive"
    status="collected"
    sha256=""
    patches_applied=""

    log "=== 処理開始: $name $version ($license) ==="
    mkdir -p "$pkg_dir"

    # [1] ソースアーカイブのダウンロード (既に存在すればスキップ)
    if [ -f "$archive_path" ]; then
        log "アーカイブ既存: $archive_path (ダウンロードスキップ)"
    else
        log "ダウンロード: $url"
        if curl -L --fail --retry 3 --connect-timeout 20 --max-time 300 \
                -o "$archive_path.part" "$url" 2>/dev/null; then
            mv "$archive_path.part" "$archive_path"
            log "ダウンロード完了: $archive"
        else
            rm -f "$archive_path.part"
            warn "ダウンロード失敗: $url (このパッケージをスキップ)"
            status="download_failed"
            # 失敗分もマニフェストに記録して処理を継続
            printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
                "$name" "$version" "$license" "$url" "$archive_path" "$sha256" "$status" "$patches_applied" >> "$TMP_MANIFEST"
            continue
        fi
    fi

    # [2] SHA256 ハッシュの算出・検証 (再計算による整合性確認)
    sha256="$(hash_file "$archive_path")"
    sha256_check="$(hash_file "$archive_path")"
    if [ "$sha256" != "$sha256_check" ]; then
        warn "SHA256 の再計算が一致しません: $name"
        status="hash_mismatch"
    fi
    log "SHA256: $sha256  ($archive)"

    # [3] ソースアーカイブの展開
    log "展開: $archive -> $pkg_dir/"
    case "$archive" in
        *.tar.xz|*.txz) tar -xf "$archive_path" -C "$pkg_dir" ;;
        *.tar.gz|*.tgz) tar -xf "$archive_path" -C "$pkg_dir" ;;
        *.tar.bz2)      tar -xf "$archive_path" -C "$pkg_dir" ;;
        *.tar)          tar -xf "$archive_path" -C "$pkg_dir" ;;
        *)              warn "未対応のアーカイブ形式: $archive" ;;
    esac

    # 展開後の最上位ディレクトリを特定
    src_dir=""
    for d in "$pkg_dir"/*/; do
        [ -d "$d" ] && src_dir="$d" && break
    done
    src_dir="${src_dir%/}"
    if [ -z "$src_dir" ]; then
        warn "展開ディレクトリが見つかりません: $name"
        status="extract_failed"
    else
        log "ソースディレクトリ: $src_dir"
    fi

    # [4] パッチの適用 (patches/<package>/ が存在する場合)
    patch_dir="$PATCHES_DIR/$name"
    if [ -d "$patch_dir" ]; then
        applied_count=0
        for patch in "$patch_dir"/*.patch; do
            [ -e "$patch" ] || continue
            if ( cd "$src_dir" && patch -p1 --no-backup-if-mismatch < "$patch" ) 2>/dev/null; then
                applied_count=$((applied_count + 1))
                log "パッチ適用: $(basename "$patch")"
                patches_applied="$patches_applied $(basename "$patch")"
            else
                warn "パッチ適用失敗: $(basename "$patch")"
            fi
        done
        [ "$applied_count" = "0" ] && patches_applied=""
    fi

    # [5] このパッケージの収集記録をマニフェスト用テンポラリに追記
    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$name" "$version" "$license" "$url" "$archive_path" "$sha256" "$status" "$patches_applied" >> "$TMP_MANIFEST"

done <<< "$(build_targets)"

# [6] ビルド設定ファイルを build/sources/config/ にコピー
for cfg in kernel-defconfig buildroot-defconfig; do
    src_cfg="$CONFIG_DIR/$cfg"
    if [ -f "$src_cfg" ]; then
        cp "$src_cfg" "$SOURCES_DIR/config/$cfg"
        log "設定ファイルコピー: $cfg -> build/sources/config/"
    else
        warn "設定ファイルが見つかりません (スキップ): $src_cfg"
    fi
done

# [7] 収集結果マニフェスト (JSON) を生成
log "マニフェスト生成: $MANIFEST_FILE"
jq -n --arg date "$DATE" '{generated_at: $date, project: "SabakanOS", components: []}' > "$MANIFEST_FILE.tmp"

while IFS='|' read -r name version license url archive_path sha256 status patches_applied; do
    [ -z "$name" ] && continue
    # ソースディレクトリの相対パスを算出
    pkg_dir="$SOURCES_DIR/$name"
    src_dir=""
    for d in "$pkg_dir"/*/; do
        [ -d "$d" ] && src_dir="$d" && break
    done
    src_dir="${src_dir%/}"
    files_entry=""
    if [ -n "$src_dir" ]; then
        rel="$(printf '%s' "$src_dir" | sed "s|^$PROJECT_ROOT/||")"
        files_entry="$rel/"
    fi
    # パッチ文字列を配列化
    patch_json="[]"
    if [ -n "$patches_applied" ]; then
        patch_json="$(printf '%s' "$patches_applied" | awk '{for(i=1;i<=NF;i++) printf "%s\"%s\"", (i>1?",":""), $i}')"
        patch_json="[$patch_json]"
    fi
    jq --arg date "$DATE" \
       --arg name "$name" --arg version "$version" --arg license "$license" \
       --arg source_url "$url" --arg archive "$archive" --arg archive_path "$archive_path" \
       --arg sha256 "$sha256" --arg status "$status" --arg files "$files_entry" \
       --argjson patches "$patch_json" \
       '.components += [{
           name: $name, version: $version, license: $license,
           source_url: $source_url, archive: $archive,
           archive_path: $archive_path, sha256: $sha256,
           status: $status, source_dir: $files, patches: $patches
       }]' "$MANIFEST_FILE.tmp" > "$MANIFEST_FILE.tmp2" && mv "$MANIFEST_FILE.tmp2" "$MANIFEST_FILE.tmp"
done < "$TMP_MANIFEST"

mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"
rm -f "$TMP_MANIFEST"

# JSON 妥当性検証
if ! jq empty "$MANIFEST_FILE" 2>/dev/null; then
    err "生成されたマニフェストが不正な JSON です: $MANIFEST_FILE"
    exit 1
fi

component_count="$(jq '.components | length' "$MANIFEST_FILE")"
log "完了: 収集対象 $component_count コンポーネント -> $MANIFEST_FILE"
exit 0
