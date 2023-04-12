#!/bin/sh
set -e

VERSION=$1

DISK_CONTENTS_DIR=$ARTIFACTDIR/disk-ws-tmp/contents

install -v $RECIPEDIR/bootloaders/isolinux/* $DISK_CONTENTS_DIR/isolinux/

install -v $RECIPEDIR/bootloaders/grub/grub.cfg $DISK_CONTENTS_DIR/boot/grub/
touch $DISK_CONTENTS_DIR/pureos
