#!/bin/sh
set -e

VERSION=$1
ARCH=$2

DISK_CONTENTS_DIR=$ARTIFACTDIR/disk-ws-tmp/contents
WS_TMP_DIR=$ARTIFACTDIR/disk-ws-tmp/tmp

DISK_INFO_DIR=$DISK_CONTENTS_DIR/.disk
mkdir -p $DISK_INFO_DIR

cd $DISK_CONTENTS_DIR
for INITRD in casper/initrd.img*
do
    cd $WS_TMP_DIR
    zcat "$DISK_CONTENTS_DIR/${INITRD}" | cpio --quiet -id conf/uuid.conf

    if [ -e conf/uuid.conf ]
    then
        mv conf/uuid.conf "$DISK_INFO_DIR/casper-uuid${INITRD#casper/initrd.img}"
    else
        echo "Failed to find casper uuid.conf in '${INITRD}'"
    fi

    rm -rf conf/
done

# write disk info string
cd $DISK_INFO_DIR
echo "embassyOS $VERSION - $ARCH Build $(date -Im)" > info

# write md5sum inventory list
cd $DISK_CONTENTS_DIR
find -type f \( -not -name "md5sum.txt" \) -exec md5sum '{}' \; > md5sum.txt
