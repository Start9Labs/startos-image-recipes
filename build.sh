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

rm -rf ./disk-ws-tmp/
echo
debos \
	-m4G \
	-c4 \
	--scratchsize=8G \
	startos-iso.yaml \
	-t arch:"${IB_TARGET_ARCH}" \
	-t version:"${VERSION_FULL}" \
	-t image:"$IMAGE_BASENAME" \
	-t results_dir:"$prep_results_dir"
echo "mv $prep_results_dir/* $RESULTS_DIR/"
mv $prep_results_dir/* $RESULTS_DIR/
