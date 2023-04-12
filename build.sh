#!/bin/sh
set -e

echo "==== StartOS Image Build ===="

echo "Building for architecture: $IB_TARGET_ARCH"

prep_results_dir="$(dirname "$(readlink -f "$0")")/results-prep"
if systemd-detect-virt -qc; then
  RESULTS_DIR="/srv/artifacts"
else
  RESULTS_DIR="$(dirname "$(readlink -f "$0")")/results"
fi
echo "Saving results in: $RESULTS_DIR"

CURRENT_DATE=$(date +%Y%m%d)

IMAGE_BASENAME=startos-${VERSION_FULL}-${CURRENT_DATE}_${IB_TARGET_ARCH}

ps --no-headers -o comm 1

mkdir -p $prep_results_dir

cd $prep_results_dir

QEMU_ARCH=${IB_TARGET_ARCH}
if [ "$QEMU_ARCH" = 'amd64' ]; then
	QEMU_ARCH=x86_64
elif [ "$QEMU_ARCH" = 'arm64' ]; then
	QEMU_ARCH=aarch64
fi

lb config -d ${IB_SUITE} -a ${IB_TARGET_ARCH} --bootstrap-qemu-arch ${IB_TARGET_ARCH} --bootstrap-qemu-static $(which qemu-${QEMU_ARCH}-static)
lb build || find / -name debootstrap.log | xargs cat

cd ..

# rm -rf ./disk-ws-tmp/
# echo
# debos \
# 	-m4G \
# 	-c4 \
# 	--scratchsize=8G \
# 	startos-iso.yaml \
# 	-t arch:"${IB_TARGET_ARCH}" \
# 	-t version:"${VERSION_FULL}" \
# 	-t image:"$IMAGE_BASENAME" \
# 	-t results_dir:"$prep_results_dir"
# echo "mv $prep_results_dir/* $RESULTS_DIR/"
mv $prep_results_dir/*.iso $RESULTS_DIR/$IMAGE_BASENAME.iso

find $RESULTS_DIR