#!/bin/sh
# SabakanOS レーンG1 — SBOM 生成スクリプト
# 所有: レーンG1 (ライセンスコンプライアンス: ソース収集・SBOM生成)
# 用途: build/source-manifest.json から SPDX 2.2 形式の SBOM と
#       ソース対応表 (SOURCE-MANIFEST.json) を生成する。
#
# 出力:
#   build/SBOM.spdx.json       SPDX 2.2 形式の SBOM
#   build/SOURCE-MANIFEST.json ソース対応表 (JSON)
#
# 他レーン所有ファイルには一切触れない。

set -u

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_FILE="$PROJECT_ROOT/build/source-manifest.json"
SBOM_FILE="$PROJECT_ROOT/build/SBOM.spdx.json"
SOURCE_MANIFEST_FILE="$PROJECT_ROOT/build/SOURCE-MANIFEST.json"

log() { printf '[generate-sbom] %s\n' "$*"; }
err() { printf '[generate-sbom] ERROR: %s\n' "$*" >&2; }

if [ ! -f "$MANIFEST_FILE" ]; then
    err "ソースマニフェストが見つかりません: $MANIFEST_FILE"
    err "先に scripts/collect-sources.sh を実行してください"
    exit 1
fi

if ! jq empty "$MANIFEST_FILE" 2>/dev/null; then
    err "ソースマニフェストが不正な JSON です: $MANIFEST_FILE"
    exit 1
fi

mkdir -p "$PROJECT_ROOT/build"

DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
DOC_NAME="SabakanOS-SBOM"
DOC_NAMESPACE="https://sabakan-os.example.org/sbom/${DATE}"

# ---------------------------------------------------------------------------
# SPDX 2.2 形式の SBOM を生成
# ---------------------------------------------------------------------------
log "SBOM 生成: $SBOM_FILE"

jq -n \
    --arg spdxVersion "SPDX-2.2" \
    --arg name "$DOC_NAME" \
    --arg namespace "$DOC_NAMESPACE" \
    --arg created "$DATE" \
    --arg creator "Tool: SabakanOS scripts/generate-sbom.sh" \
    '{
        spdxVersion: $spdxVersion,
        name: $name,
        documentNamespace: $namespace,
        creationInfo: {
            created: $created,
            creators: [$creator]
        },
        packages: []
    }' > "$SBOM_FILE.tmp"

# source-manifest.json の各コンポーネントを SPDX Package に変換
jq -c '.components[]' "$MANIFEST_FILE" | while IFS= read -r comp; do
    name="$(printf '%s' "$comp" | jq -r '.name')"
    version="$(printf '%s' "$comp" | jq -r '.version // ""')"
    license="$(printf '%s' "$comp" | jq -r '.license // "NOASSERTION"')"
    source_url="$(printf '%s' "$comp" | jq -r '.source_url // ""')"
    sha256="$(printf '%s' "$comp" | jq -r '.sha256 // ""')"
    source_dir="$(printf '%s' "$comp" | jq -r '.source_dir // ""')"

    # SPDX Package 構築
    pkg_json="$(jq -n \
        --arg name "$name" \
        --arg version "$version" \
        --arg license "$license" \
        --arg downloadLocation "$source_url" \
        --arg sha256 "$sha256" \
        --arg files "$source_dir" \
        '{
            name: $name,
            version: $version,
            licenseDeclared: $license,
            downloadLocation: $downloadLocation,
            checksum: (if ($sha256 | length) > 0 then
                {algorithm: "SHA256", checksumValue: $sha256}
            else
                {algorithm: "SHA256", checksumValue: ""}
            end),
            files: (if ($files | length) > 0 then [$files] else [] end)
        }')"

    # SBOM ファイルにパッケージを追加
    tmp_out="$(jq --argjson pkg "$pkg_json" '.packages += [$pkg]' "$SBOM_FILE.tmp")"
    printf '%s' "$tmp_out" > "$SBOM_FILE.tmp"
done

mv "$SBOM_FILE.tmp" "$SBOM_FILE"

# ---------------------------------------------------------------------------
# SOURCE-MANIFEST.json (ソース対応表) を生成
# ---------------------------------------------------------------------------
log "ソース対応表生成: $SOURCE_MANIFEST_FILE"

jq '[.components[] | {
    component: .name,
    version: .version,
    license: .license,
    upstream_url: .source_url,
    source_url: .source_url,
    sha256: .sha256,
    local_path: .archive_path,
    status: .status
}]' "$MANIFEST_FILE" > "$SOURCE_MANIFEST_FILE.tmp"

mv "$SOURCE_MANIFEST_FILE.tmp" "$SOURCE_MANIFEST_FILE"

# 生成物の妥当性検証
if ! jq empty "$SBOM_FILE" 2>/dev/null; then
    err "生成された SBOM が不正な JSON です: $SBOM_FILE"
    exit 1
fi
if ! jq empty "$SOURCE_MANIFEST_FILE" 2>/dev/null; then
    err "生成されたソース対応表が不正な JSON です: $SOURCE_MANIFEST_FILE"
    exit 1
fi

pkg_count="$(jq '.packages | length' "$SBOM_FILE")"
log "完了: SBOM パッケージ数 $pkg_count -> $SBOM_FILE"
log "       ソース対応表 -> $SOURCE_MANIFEST_FILE"
exit 0
