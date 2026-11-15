#!/bin/sh
# macOS の BSD ar は -D (deterministic) オプションをサポートしないため、
# -D / rcsD / cDPrsT などから D/P を除去してから /usr/bin/ar を呼び出すラッパー。
# kbuild は ARFLAGS=cDPrsT のように D/P を他フラグと結合して渡すことがあり、
# その際も D/P だけを除去する。オブジェクトファイルが1つも無い空アーカイブの
# 場合は BSD ar が "no archive members specified" で失敗するため、
# 代わりに空のアーカイブファイルを作成して返す。
args=""
objs=0
archive=""
dest=""
srcs=""
for a in "$@"; do
    case "$a" in
        -D|-D=*) ;;                       # -D / -D=* は除去
        -*)                               # -xxxDP 形式のフラグ: D/P だけ除去
            a="$(printf '%s' "$a" | tr -d 'DP')"
            args="$args $a"
            ;;
        *.o)                              # オブジェクトファイル
            args="$args $a"
            objs=1
            ;;
        *.a)                              # アーカイブ: 1つ目を宛先、2つ目以降はマージ元
            if [ -z "$dest" ]; then
                dest="$a"
                args="$args $a"
            else
                srcs="$srcs $a"
            fi
            ;;
        *)                                # その他: 純粋英字ならフラグ文字列と見做して D/P 除去,
            case "$a" in                  # パス/拡張子を含むものはそのまま
                *[!a-zA-Z]*) args="$args $a" ;;
                *) a="$(printf '%s' "$a" | tr -d 'DP')"; args="$args $a" ;;
            esac
            ;;
    esac
done

# マージ元アーカイブからオブジェクトを抽出して宛先アーカイブに追加
for src in $srcs; do
    tmpdir=$(mktemp -d 2>/dev/null || echo /tmp/arwrap$$)
    mkdir -p "$tmpdir"
    (cd "$tmpdir" && ar x "$src" 2>/dev/null) || true
    # 抽出した .o ファイルを宛先に追加 (glob が空の場合はエラーを無視)
    set -- "$tmpdir"/*.o
    if [ -e "$1" ]; then
        /usr/bin/ar r "$dest" "$@" 2>/dev/null || true
    fi
    rm -rf "$tmpdir"
done

# 直接渡されたオブジェクトファイルを宛先に追加 (ar_builtin 用)
if [ "$objs" = "1" ]; then
    exec /usr/bin/ar $args
    exit 0
fi

# 何も追加対象がない場合は空アーカイブを作成
if [ -z "$srcs" ] && [ -n "$dest" ]; then
    rm -f "$dest"
    : > "$dest"
    exit 0
fi

# マージのみの場合は正常終了 (dest にオブジェクトが追加済み)
if [ -n "$dest" ]; then
    exit 0
fi

exec /usr/bin/ar $args
