#!/bin/sh
set -e

cp $ROOTDIR/boot/vmlinuz-* \
    $ARTIFACTDIR/disk-ws-tmp/contents/casper/vmlinuz
cp $ROOTDIR/boot/initrd.img-* \
    $ARTIFACTDIR/disk-ws-tmp/contents/casper/initrd.img
