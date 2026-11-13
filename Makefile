# SabakanOS レーンA — ビルドシステム Makefile
#
# 所有: レーンA (ビルドシステム・ルートFS)
# 対象ターゲット: build-kernel, build-rootfs, clean, help
#
# 他レーン (B〜E) が所有する boot/, scripts/build-iso.sh,
# scripts/run-qemu.sh, packages/, README.md, .github/workflows/ には触らない。

SHELL := /bin/sh

.PHONY: all build-kernel build-rootfs clean help

all: help

build-kernel:	## Linux カーネルをビルド (kernel.org LTS 6.18.63, x86_64)
	@$(CURDIR)/scripts/build-kernel.sh

build-rootfs:	## ルートファイルシステムを生成 (rootfs/)
	@$(CURDIR)/scripts/build-rootfs.sh

clean:	## ビルド成果物を削除 (build/, rootfs/, tool/)
	@rm -rf build rootfs tool
	@echo "[make] clean 完了: build/, rootfs/, tool/ を削除しました"

help:	## 利用可能なターゲットを表示
	@echo "SabakanOS レーンA ビルドターゲット"
	@echo ""
	@echo "  build-kernel   Linux カーネルのソース取得・設定・コンパイル (kernel.org LTS)"
	@echo "  build-rootfs   ルートファイルシステム (rootfs/) の生成"
	@echo "  clean          ビルド成果物 (build/, rootfs/, tool/) の削除"
	@echo "  help           このヘルプを表示"
	@echo ""
	@echo "実行例: make build-rootfs"
