#!/bin/sh
# SabakanOS テストスイート (純 POSIX sh、依存なし)
#
# 使い方:
#   ./tests/run-tests.sh        # rootfs/ と build/ が必要 (make build-rootfs / make iso 後)
#
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0
fail=0
skip=0

assert() {
    # $1: 判定メッセージ, $2: 条件 (0=真/成功, 1=偽/失敗)
    if [ "$2" -eq 0 ]; then
        echo "PASS: $1"
        pass=$((pass + 1))
    else
        echo "FAIL: $1"
        fail=$((fail + 1))
    fi
}

# ---- 0. 前提確認 ----
if [ ! -d "$ROOT/rootfs" ]; then
    echo "rootfs/ が存在しません。先に 'make build-rootfs' を実行してください" >&2
    exit 1
fi

# ---- 1. rootfs/bin/sh -> busybox が解決する ----
if [ -L "$ROOT/rootfs/bin/sh" ]; then
    target="$(readlink "$ROOT/rootfs/bin/sh")"
    if [ "$target" = "busybox" ]; then
        assert "rootfs/bin/sh は busybox へのシンボルリンク" 0
    else
        assert "rootfs/bin/sh のリンク先が busybox (実態: $target)" 1
    fi
else
    assert "rootfs/bin/sh はシンボルリンク" 1
fi

if [ -s "$ROOT/rootfs/bin/busybox" ]; then
    assert "rootfs/bin/busybox 実体が存在し非空" 0
else
    assert "rootfs/bin/busybox 実体が存在し非空" 1
fi

# ---- 2. rootfs/init / etc/passwd / etc/hostname 存在 ----
for f in init etc/passwd etc/hostname etc/group etc/inittab etc/profile; do
    if [ -e "$ROOT/rootfs/$f" ]; then
        assert "rootfs/$f 存在" 0
    else
        assert "rootfs/$f 存在" 1
    fi
done

# ---- 3. build/initramfs.img 生成・非空 ----
if [ -s "$ROOT/build/initramfs.img" ]; then
    assert "build/initramfs.img 生成・非空" 0
else
    assert "build/initramfs.img 生成・非空" 1
fi

# ---- 4. build/sabakanos.iso 生成・非空 (存在する場合のみ) ----
if [ -f "$ROOT/build/sabakanos.iso" ]; then
    if [ -s "$ROOT/build/sabakanos.iso" ]; then
        assert "build/sabakanos.iso 生成・非空" 0
    else
        assert "build/sabakanos.iso 生成・非空" 1
    fi
else
    echo "SKIP: build/sabakanos.iso が存在しません (make iso 未実行)"
    skip=$((skip + 1))
fi

# ---- 5. QEMU ブートでシェル到達 (CI のみ、ここではスキップ) ----
echo "SKIP: QEMU ブートテスト (CI 専用: make test / scripts/run-qemu.sh)"
skip=$((skip + 1))

echo "----"
echo "PASS: $pass  FAIL: $fail  SKIP: $skip"
if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
