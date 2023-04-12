#!/bin/sh
set -e

IMAGE_NAME=$1
RESULTS_DIR=$2

# write checksum files
cd $RESULTS_DIR
find -type f \( -not -name "$IMAGE_NAME.checksums_*" \) -exec sha256sum '{}' \; > $IMAGE_NAME.checksums_sha256.txt
find -type f \( -not -name "$IMAGE_NAME.checksums_*" \) -exec b2sum '{}' \; > $IMAGE_NAME.checksums_blake2.txt
