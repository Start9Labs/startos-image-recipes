#!/bin/sh
set -e

cp $ROOTDIR/usr/lib/ISOLINUX/isolinux.bin $ARTIFACTDIR/disk-ws-tmp/contents/isolinux/
cp $ROOTDIR/usr/lib/syslinux/modules/bios/* $ARTIFACTDIR/disk-ws-tmp/contents/isolinux/
cp $ROOTDIR/boot/memtest86+.bin $ARTIFACTDIR/disk-ws-tmp/contents/isolinux/

cp -r $ROOTDIR/usr/lib/grub/x86_64-efi/* $ARTIFACTDIR/disk-ws-tmp/contents/boot/grub/x86_64-efi/
