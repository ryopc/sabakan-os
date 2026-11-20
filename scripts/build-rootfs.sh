#!/bin/sh
#
# scripts/build-rootfs.sh — SabakanOS レーンA: ルートファイルシステム生成
#
# 概要:
#   Buildroot (musl / x86_64) が利用可能な場合はその defconfig を適用し、
#   利用できない場合は独自シェルスクリプトでベース rootfs を rootfs/ に構築する。
#   本スクリプトは macOS 等のホストでも必ず正常終了し、chroot 用の雛形
#   ディレクトリ構造と初期設定ファイルを生成する。
#
# ディレクトリ構造:
#   bin sbin etc usr/bin usr/sbin usr/lib lib lib64
#   var proc sys dev boot home root tmp opt
#
# 出力:
#   rootfs/  (init, /etc/passwd, /etc/group, /etc/shadow, /etc/fstab,
#             /etc/inittab, /etc/profile, /etc/init.d/rcS, bin/sh リンク等)

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

BUILDROOT_VER="2026.08.1"
BUILDROOT_TAR="buildroot-${BUILDROOT_VER}.tar.xz"
BUILDROOT_URL="https://buildroot.org/downloads/${BUILDROOT_TAR}"

BUILD_DIR="${ROOT}/build"
BR_DIR="${BUILD_DIR}/buildroot"
DEFCONFIG="${ROOT}/config/buildroot-defconfig"

TARGET="${ROOT}/rootfs"

log()  { printf '[build-rootfs] %s\n' "$*"; }
warn() { printf '[build-rootfs][警告] %s\n' "$*" >&2; }

mkdir -p "${BUILD_DIR}" "${TARGET}"

# ---- 0. Buildroot の導入 (tarball ダウンロード) ----
if [ ! -f "${BR_DIR}/Makefile" ]; then
    log "Buildroot ${BUILDROOT_VER} をダウンロード中..."
    if ! curl -fsSL --retry 3 --connect-timeout 20 \
            -o "${BUILD_DIR}/${BUILDROOT_TAR}" "${BUILDROOT_URL}"; then
        warn "Buildroot のダウンロードに失敗しました。代替ルートで rootfs を生成します。"
    else
        tar -xf "${BUILD_DIR}/${BUILDROOT_TAR}" -C "${BUILD_DIR}"
        rm -f "${BUILD_DIR}/${BUILDROOT_TAR}"
        if [ -d "${BUILD_DIR}/buildroot-${BUILDROOT_VER}" ]; then
            mv "${BUILD_DIR}/buildroot-${BUILDROOT_VER}" "${BR_DIR}"
        fi
        log "Buildroot 導入完了: ${BR_DIR}"
    fi
else
    log "Buildroot は既に導入済みです: ${BR_DIR}"
fi

# ---- 1. Buildroot defconfig の適用 (可能な場合) ----
if [ -f "${BR_DIR}/Makefile" ] && [ -f "${DEFCONFIG}" ]; then
    log "Buildroot defconfig を適用中: config/buildroot-defconfig (musl/x86_64/最小)"
    if ( cd "${BR_DIR}" && make BR2_DEFCONFIG="${DEFCONFIG}" defconfig >/dev/null 2>&1 ); then
        log "Buildroot defconfig 適用完了"
    else
        warn "Buildroot defconfig の適用に失敗しました。rootfs 生成は続行します。"
    fi
fi

# ---- 2. ベース rootfs ディレクトリ構造を構築 (代替案: 常に実行) ----
log "ルートファイルシステムを構築中: ${TARGET}"

mkdir -p "${TARGET}"/bin
mkdir -p "${TARGET}"/sbin
mkdir -p "${TARGET}"/etc
mkdir -p "${TARGET}"/etc/init.d
mkdir -p "${TARGET}"/etc/profile.d
mkdir -p "${TARGET}"/usr/bin
mkdir -p "${TARGET}"/usr/sbin
mkdir -p "${TARGET}"/usr/lib
mkdir -p "${TARGET}"/lib
mkdir -p "${TARGET}"/lib64
mkdir -p "${TARGET}"/var
mkdir -p "${TARGET}"/var/log
mkdir -p "${TARGET}"/var/run
mkdir -p "${TARGET}"/var/tmp
mkdir -p "${TARGET}"/proc
mkdir -p "${TARGET}"/sys
mkdir -p "${TARGET}"/dev
mkdir -p "${TARGET}"/boot
mkdir -p "${TARGET}"/home
mkdir -p "${TARGET}"/root
mkdir -p "${TARGET}"/tmp
mkdir -p "${TARGET}"/opt

# ---- 3. init テンプレート ----
cat > "${TARGET}/init" <<'EOF'
#!/bin/sh
# SabakanOS 初期プロセス (PID 1 / init)
# カーネルが initramfs/rootfs から最初に実行するプログラム。

mount -t proc proc /proc 2>/dev/null || true
mount -t sysfs sys /sys 2>/dev/null || true
mount -t devtmpfs dev /dev 2>/dev/null || mkdir -p /dev

hostname sabakan 2>/dev/null || true

# レーンC 等が配置した起動スクリプトを実行
/etc/init.d/rcS 2>/dev/null || true

# 対話シェルを起動 (chroot 動作確認用)
exec /bin/sh
EOF
chmod 755 "${TARGET}/init"

# ---- 4. パスワードファイル雛形 ----
cat > "${TARGET}/etc/passwd" <<'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

cat > "${TARGET}/etc/group" <<'EOF'
root:x:0:
EOF

cat > "${TARGET}/etc/shadow" <<'EOF'
root:*:18000:0:99999:7:::
EOF
chmod 600 "${TARGET}/etc/shadow"

# ---- 5. fstab / inittab / profile / hostname ----
cat > "${TARGET}/etc/fstab" <<'EOF'
proc	/proc	proc	defaults	0	0
sysfs	/sys	sysfs	defaults	0	0
devtmpfs	/dev	devtmpfs	defaults	0	0
EOF

cat > "${TARGET}/etc/inittab" <<'EOF'
::sysinit:/etc/init.d/rcS
::askfirst:/bin/sh
::ctrlaltdel:/bin/sh
::shutdown:/bin/umount -a -r
EOF

cat > "${TARGET}/etc/profile" <<'EOF'
# SabakanOS シェルプロファイル
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
PS1='sabakan:\w # '
EOF

# --- デフォルトシェル一覧 ---
cat > "${TARGET}/etc/shells" <<'EOF'
# SabakanOS 有効ログインシェル
/bin/busybox
/bin/sh
/bin/zsh
EOF

echo "sabakan" > "${TARGET}/etc/hostname"

# ---- 5b. 日本語環境設定 (ja_JP.UTF-8, Asia/Tokyo, jp106) ----
# ロケール
mkdir -p "${TARGET}/etc/profile.d"
cat > "${TARGET}/etc/locale.conf" <<'EOF'
# SabakanOS 日本語ロケール
LANG=ja_JP.UTF-8
LC_TIME=ja_JP.UTF-8
LC_NUMERIC=ja_JP.UTF-8
LC_MONETARY=ja_JP.UTF-8
LC_PAPER=ja_JP.UTF-8
LC_MEASUREMENT=ja_JP.UTF-8
EOF

# タイムゾーン
echo "Asia/Tokyo" > "${TARGET}/etc/timezone"
ln -sf ../usr/share/zoneinfo/Asia/Tokyo "${TARGET}/etc/localtime" 2>/dev/null || true

# キーボード (106キー / 日本語)
cat > "${TARGET}/etc/vconsole.conf" <<'EOF'
KEYMAP=jp106
EOF
mkdir -p "${TARGET}/etc/conf.d"
cat > "${TARGET}/etc/conf.d/keymaps" <<'EOF'
# SabakanOS キーボード設定
keymap="jp106"
EOF

# プロファイル用ロケール環境変数
cat > "${TARGET}/etc/profile.d/locale.sh" <<'EOF'
# SabakanOS ロケール環境変数
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8
export LC_CTYPE=ja_JP.UTF-8
export TZ=Asia/Tokyo
EOF

# ---- 5c. デスクトップ環境設定 (M2: X11 / 日本語入力 / 軽量WM) ----
# IBus + Mozc 入力メソッド環境変数
cat > "${TARGET}/etc/profile.d/ibus.sh" <<'EOF'
# SabakanOS IBus + Mozc 日本語入力環境変数
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
EOF

# X11 セッション起動スクリプト (.xprofile)
mkdir -p "${TARGET}/etc/skel"
cat > "${TARGET}/etc/skel/.xprofile" <<'EOF'
# SabakanOS X11 セッション起動スクリプト
ibus-daemon -drx &
EOF
chmod 755 "${TARGET}/etc/skel/.xprofile"

# Openbox 設定
mkdir -p "${TARGET}/etc/xdg/openbox"
cat > "${TARGET}/etc/xdg/openbox/autostart" <<'EOF'
# SabakanOS Openbox 自動起動スクリプト
ibus-daemon -drx &
EOF

cat > "${TARGET}/etc/xdg/openbox/menu.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
    <menu id="root-menu" label="SabakanOS">
        <item label="ターミナル"><action name="Execute"><execute>xterm</execute></action></item>
        <item label="終了"><action name="Exit"/></item>
    </menu>
</openbox_menu>
EOF

# X セッション初期化スクリプト
mkdir -p "${TARGET}/etc/X11/xinit"
cat > "${TARGET}/etc/X11/xinit/xinitrc" <<'EOF'
#!/bin/sh
# SabakanOS X セッション初期化スクリプト
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
ibus-daemon -drx &
exec openbox
EOF
chmod 755 "${TARGET}/etc/X11/xinit/xinitrc"

# デスクトップセッションエントリ
mkdir -p "${TARGET}/usr/share/xsessions"
cat > "${TARGET}/usr/share/xsessions/sabakan-openbox.desktop" <<'EOF'
[Desktop Entry]
Name=SabakanOS Openbox
Comment=Lightweight Japanese Desktop (Openbox + IBus + Mozc)
Exec=/etc/X11/xinit/xinitrc
TryExec=/usr/bin/openbox
Type=XSession
EOF

# ---- 6. 起動スクリプト rcS ----
cat > "${TARGET}/etc/init.d/rcS" <<'EOF'
#!/bin/sh
# SabakanOS 起動スクリプト
mount -a 2>/dev/null || true
echo "SabakanOS 起動完了"
EOF
chmod 755 "${TARGET}/etc/init.d/rcS"

# ---- 7. /bin/sh -> busybox へのシンボリックリンク ----
# busybox 本体は Buildroot / クロスツールチェインで生成し、
# ビルド後に rootfs/bin へ配置する。ここではリンクのみを作成する。
ln -sf busybox "${TARGET}/bin/sh"

# レーンC 配置の既存ファイル (etc/keymaps, locale.gen 等) は上書きしない。

log "完了: ルートファイルシステムを生成しました -> ${TARGET}"
log "ディレクトリ: bin sbin etc usr/bin usr/sbin usr/lib lib lib64 var proc sys dev boot home root tmp opt"
log "主なファイル: init, etc/passwd, etc/group, etc/shadow, etc/fstab, etc/inittab, etc/profile, etc/profile.d/locale.sh, etc/profile.d/ibus.sh, etc/locale.conf, etc/timezone, etc/vconsole.conf, etc/xdg/openbox/autostart, etc/xdg/openbox/menu.xml, etc/X11/xinit/xinitrc, etc/skel/.xprofile, usr/share/xsessions/sabakan-openbox.desktop, etc/init.d/rcS"
exit 0
