#!/bin/sh
set -e
set -x

export DEBIAN_FRONTEND=noninteractive
apt-get install -yq \
	live-build \
	procps \
	systemd \
	binfmt-support \
	qemu-user-static \
	qemu-system-x86 \
	qemu-system-aarch64 \
	xorriso \
	isolinux \
	ca-certificates \
	curl \
	gpg
