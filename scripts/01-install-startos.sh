#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt install -y /deb/embassyos_0.3.x-1_amd64.deb
rm -rf /deb

rm /usr/local/bin/apt-get