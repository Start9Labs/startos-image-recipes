#!/bin/bash
set -e

# Copyright (C) 2016-2020 The Debian Live team
# Copyright (C) 2016 Adrian Gibanel Lopez <adrian15sgd@gmail.com>
# Copyright (C) 2020 Matthias Klumpp <matthias.klumpp@puri.sm>
#
# Licensed under the GNU General Public License Version 3

if [ -z "$1" ]; then
	echo "usage: $0 ARCH"
	exit 1
fi

ARCH="$1"
DISK_CONTENTS_DIR=$ARTIFACTDIR/disk-ws-tmp/contents
WS_TMP_DIR=$ARTIFACTDIR/disk-ws-tmp/tmp
TOOLS_DIR=$RECIPEDIR/scripts/disk/tools

export SOURCE_DATE_EPOCH="$(date '+%s')"

gen_efi_boot_img() {
	local platform="$1"
	local efi_name="$2"
	local outdir="grub-efi-temp-${platform}"
	${TOOLS_DIR}/efi-image "${WS_TMP_DIR}/$outdir" "$platform" "$efi_name"
	mkdir -p ${WS_TMP_DIR}/grub-efi-temp/EFI/boot
	mcopy -m -n -i ${WS_TMP_DIR}/$outdir/efi.img '::efi/boot/boot*.efi' ${WS_TMP_DIR}/grub-efi-temp/EFI/boot
	rm ${WS_TMP_DIR}/$outdir/efi.img
	cp -dR "${WS_TMP_DIR}"/$outdir/* "${WS_TMP_DIR}/grub-efi-temp/"

	# Secure Boot support:
	# - create the EFI directory in the ESP with uppercase letters to make
	#   certain firmwares (eg: TianoCore) happy
	# - use shim as the boot<arch>.efi that gets loaded first by the firmware
	# - drop a grub.cfg (same reason as below) in the cfg directory as configured
	#   by the signed grub efi binary creation. This is set dynamically when grub2 is
	#   built with the ouput of dpkg-vendor, and can be overridden by the builder, so
	#   we do the same here in live-build.
	# - the source paths are taken from shim-signed:
	#    https://packages.debian.org/sid/amd64/shim-signed/filelist
	#   and grub-efi-amd64-signed, currently in Ubuntu:
	#    https://packages.ubuntu.com/xenial/amd64/grub-efi-amd64-signed/filelist
	#    https://packages.ubuntu.com/bionic/arm64/grub-efi-arm64-signed/filelist
	#   E.g., gcdx64.efi.signed is the boot loader for removable device, like CD or
	#   USB flash drive, while grubx64.efi.signed is for hard drive.
	#   Therefore here gcdx64.efi.signed is used for amd64 and gcdaa64.efi.signed is
	#   for arm64.
	if [ -r /usr/lib/grub/$platform-signed/gcd$efi_name.efi.signed -a \
			-r /usr/lib/shim/shim$efi_name.efi.signed -a \
			"${UEFI_SECURE_BOOT}" != "disable" ]; then
		cp -dR /usr/lib/grub/$platform-signed/gcd$efi_name.efi.signed \
			${WS_TMP_DIR}/grub-efi-temp/EFI/boot/grub$efi_name.efi
		cp -dR /usr/lib/shim/shim$efi_name.efi.signed \
			${WS_TMP_DIR}/grub-efi-temp/EFI/boot/boot$efi_name.efi
	fi
}

case "${ARCH}" in
	amd64)
		gen_efi_boot_img "x86_64-efi" "x64"
		;;
	arm64)
		gen_efi_boot_img "arm64-efi" "aa64"
		;;
	*)
		echo "Invalid architecture: $arch!"
		exit 1
esac


# On some platforms the EFI grub image will be loaded, so grub's root
# variable will be set to the EFI partition. This means that grub will
# look in that partition for a grub.cfg file, and even if it finds it
# it will not be able to find the vmlinuz and initrd.
# Drop a minimal grub.cfg in the EFI partition that sets the root and prefix
# to whatever partition holds the /.disk/info file, and load the grub
# config from that same partition.
mkdir -p ${WS_TMP_DIR}/grub-efi-temp-cfg
cat >${WS_TMP_DIR}/grub-efi-temp-cfg/grub.cfg <<EOF
search --set=root --file /.disk/info
set prefix=(\$root)/boot/grub
configfile (\$root)/boot/grub/grub.cfg
EOF
# Set the timestamp within the efi.img file
touch ${WS_TMP_DIR}/grub-efi-temp-cfg/grub.cfg -d@${SOURCE_DATE_EPOCH}

# The code below is adapted from tools/boot/jessie/boot-x86
# in debian-cd

# Stuff the EFI boot files into a FAT filesystem, making it as
# small as possible.  24KiB headroom seems to be enough;
# (x+31)/32*32 rounds up to multiple of 32.
# This is the same as in efi-image, but we need to redo it here in
# the case of a multi-arch amd64/i386 image

size=0
for file in ${WS_TMP_DIR}/grub-efi-temp/EFI/boot/*.efi \
		${WS_TMP_DIR}/grub-efi-temp-cfg/grub.cfg; do
	size=$(($size + $(stat -c %s "$file")))
done

# directories: EFI EFI/boot boot boot/grub
size=$(($size + 4096 * 4))

blocks=$((($size / 1024 + 55) / 32 * 32 ))

rm -f ${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img
# The VOLID must be (truncated to) a 32bit hexadecimal number
mkfs.msdos -C "${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img" $blocks -i $(printf "%08x" $((${SOURCE_DATE_EPOCH}%4294967296))) >/dev/null
mmd -i "${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img" ::EFI
mmd -i "${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img" ::EFI/boot
mcopy -m -o -i "${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img" ${WS_TMP_DIR}/grub-efi-temp/EFI/boot/*.efi \
	"::EFI/boot"

mmd -i "${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img" ::boot
mmd -i "${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img" ::boot/grub
mcopy -m -o -i "${WS_TMP_DIR}/grub-efi-temp/boot/grub/efi.img" ${WS_TMP_DIR}/grub-efi-temp-cfg/grub.cfg \
	"::boot/grub"

cp -dR ${WS_TMP_DIR}/grub-efi-temp/* ${DISK_CONTENTS_DIR}
