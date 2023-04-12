#!/bin/sh
set -e
set -x

export DEBIAN_FRONTEND=noninteractive
apt-get install -yq \
	cpio \
	debos \
	dosfstools \
	grub-common \
	grub-efi-amd64-bin \
	grub-pc-bin \
	kmod \
	isolinux \
	librsvg2-bin \
	mtools \
	squashfs-tools \
	udev \
	xorriso \
	zsync \
	qemu-system-x86 \
	fakemachine