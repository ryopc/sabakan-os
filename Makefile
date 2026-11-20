# SabakanOS レーンA — ビルドシステム Makefile
#
# 所有: レーンA (ビルドシステム・ルートFS)
# 対象ターゲット: build-kernel, build-rootfs, clean, help, iso, test, install, source-bundle
#
# 他レーン (B〜E) が所有する boot/, scripts/build-iso.sh,
# scripts/run-qemu.sh, packages/, README.md, .github/workflows/ には触らない。

SHELL := /bin/sh

.PHONY: all build-kernel build-rootfs clean help iso test install source-bundle

all: help

build-kernel:	## Linux カーネルをビルド (ARCH 環境変数で指定, 既定 x86_64)
	@ARCH="${ARCH:-x86_64}" $(CURDIR)/scripts/build-kernel.sh "$$ARCH"

build-rootfs:	## ルートファイルシステムを生成 (rootfs/)
	@$(CURDIR)/scripts/build-rootfs.sh

iso:	## ブート可能 ISO イメージを生成 (build/sabakanos.iso)
	@$(CURDIR)/scripts/build-iso.sh

test:	## QEMU で ISO を起動してブート確認
	@$(CURDIR)/scripts/run-qemu.sh

install:	## ISO を USB メモリに書き込む (DEVICE 必須)
	@if [ -z "${DEVICE}" ]; then \
		echo "[make][エラー] DEVICE 環境変数が未指定です。例: make install DEVICE=/dev/sdb" >&2; \
		echo "       警告: dd は指定デバイスを完全に上書きします。lsblk 等でデバイスを確認してください。" >&2; \
		exit 1; \
	fi
	@if [ ! -f build/sabakanos.iso ]; then \
		echo "[make][エラー] build/sabakanos.iso が存在しません。先に make iso を実行してください。" >&2; \
		exit 1; \
	fi
	@echo "[make] ISO を ${DEVICE} に書き込みます (dd bs=4M oflag=sync)"
	@sudo dd if=build/sabakanos.iso of="${DEVICE}" bs=4M status=progress oflag=sync

source-bundle:	## ソース収集・SBOM 生成とソースバンドルを作成 (build/source/)
	@$(CURDIR)/scripts/collect-sources.sh
	@$(CURDIR)/scripts/generate-sbom.sh
	@mkdir -p build/source
	@tar -C build/sources -cf - . | zstd -19 -T0 -o build/source/sabakanos-source.tar.zst
	@echo "[make] source-bundle 完了: build/source/sabakanos-source.tar.zst"

clean:	## ビルド成果物を削除 (build/, rootfs/, tool/)
	@rm -rf build rootfs tool
	@echo "[make] clean 完了: build/, rootfs/, tool/ を削除しました"

help:	## 利用可能なターゲットを表示
	@echo "SabakanOS レーンA ビルドターゲット"
	@echo ""
	@echo "  build-kernel   Linux カーネルのソース取得・設定・コンパイル (kernel.org LTS)"
	@echo "  build-rootfs   ルートファイルシステム (rootfs/) の生成"
	@echo "  iso            ブート可能 ISO イメージを生成 (build/sabakanos.iso)"
	@echo "  test           QEMU で ISO を起動してブート確認"
	@echo "  install        ISO を USB メモリに書き込む (DEVICE 環境変数必須)"
	@echo "  source-bundle  ソース収集・SBOM 生成とソースバンドルを作成"
	@echo "  clean          ビルド成果物 (build/, rootfs/, tool/) の削除"
	@echo "  help           このヘルプを表示"
	@echo ""
	@echo "実行例: make build-rootfs"
