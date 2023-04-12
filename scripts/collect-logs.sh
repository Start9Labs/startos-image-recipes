#!/bin/sh
set -e

BINFO_DIR=/build-info
mkdir -p $BINFO_DIR

mv /var/log/bootstrap.log $BINFO_DIR
cp /var/log/dpkg.log $BINFO_DIR

dpkg-query -W > $BINFO_DIR/packages.manifest
