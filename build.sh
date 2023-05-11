#!/bin/bash
set -e

echo "==== StartOS Image Build ===="

echo "Building for architecture: $IB_TARGET_ARCH"

base_dir="$(dirname "$(readlink -f "$0")")"
prep_results_dir="$base_dir/results-prep"
if systemd-detect-virt -qc; then
  RESULTS_DIR="/srv/artifacts"
else
  RESULTS_DIR="$base_dir/results"
fi
echo "Saving results in: $RESULTS_DIR"

CURRENT_DATE=$(date +%Y%m%d)

IMAGE_BASENAME=startos-${VERSION_FULL}-${CURRENT_DATE}_${IB_TARGET_PLATFORM}

mkdir -p $prep_results_dir

cd $prep_results_dir

QEMU_ARCH=${IB_TARGET_ARCH}
BOOTLOADERS=grub-efi,syslinux
if [ "$QEMU_ARCH" = 'amd64' ]; then
	QEMU_ARCH=x86_64
elif [ "$QEMU_ARCH" = 'arm64' ]; then
	QEMU_ARCH=aarch64
  BOOTLOADERS=grub-efi
fi
NON_FREE=
if [[ "${IB_TARGET_PLATFORM}" =~ -nonfree$ ]] || [ "${IB_TARGET_PLATFORM}" = "raspberrypi" ]; then
  NON_FREE=1
fi

if [ "$QEMU_ARCH" != "$(uname -m)" ]; then
  update-binfmts --import qemu-$QEMU_ARCH
fi

ARCHIVE_AREAS="main contrib"
if [ "$NON_FREE" = 1 ]; then
  ARCHIVE_AREAS="main contrib non-free"
fi

PLATFORM_CONFIG_EXTRAS=
if [ "${IB_TARGET_PLATFORM}" = "raspberrypi" ]; then
  PLATFORM_CONFIG_EXTRAS="$PLATFORM_CONFIG_EXTRAS --firmware-binary false"
	PLATFORM_CONFIG_EXTRAS="$PLATFORM_CONFIG_EXTRAS --firmware-chroot false"
  # BEGIN stupid ugly hack
  # The actual name of the package is `raspberrypi-kernel`
  # live-build determines thte name of the package for the kernel by combining the `linux-packages` flag, with the `linux-flavours` flag
  # the `linux-flavours` flag defaults to the architecture, so there's no way to remove the suffix.
  # So we're doing this, cause thank the gods our package name contains a hypen. Cause if it didn't we'd be SOL
	PLATFORM_CONFIG_EXTRAS="$PLATFORM_CONFIG_EXTRAS --linux-packages raspberrypi"
	PLATFORM_CONFIG_EXTRAS="$PLATFORM_CONFIG_EXTRAS --linux-flavours kernel"
  # END stupid ugly hack
fi

cat > /etc/wgetrc << EOF
retry_connrefused = on
tries = 100
EOF
lb config \
  --backports true \
  --bootappend-live "boot=live noautologin" \
  --bootloaders $BOOTLOADERS \
  --mirror-bootstrap "https://deb.debian.org/debian/" \
  -d ${IB_SUITE} \
  -a ${IB_TARGET_ARCH} \
  --bootstrap-qemu-arch ${IB_TARGET_ARCH} \
  --bootstrap-qemu-static $(which qemu-${QEMU_ARCH}-static) \
  --archive-areas "${ARCHIVE_AREAS}" \
  $PLATFORM_CONFIG_EXTRAS

# Overlays
mkdir -p config/includes.chroot
cp -r $base_dir/overlays/* config/includes.chroot/

# Archives

mkdir -p config/archives

if [ "${IB_TARGET_PLATFORM}" = "raspberrypi" ]; then
  curl -fsSL https://archive.raspberrypi.org/debian/raspberrypi.gpg.key | gpg --dearmor -o config/archives/raspi.key
  echo "deb https://archive.raspberrypi.org/debian/ ${IB_SUITE} main" > config/archives/raspi.list
fi

curl -fsSL https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc > config/archives/tor.key
echo "deb [arch=${IB_TARGET_ARCH} signed-by=/etc/apt/trusted.gpg.d/tor.key.gpg] https://deb.torproject.org/torproject.org ${IB_SUITE} main" > config/archives/tor.list

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o config/archives/docker.key
echo "deb [arch=${IB_TARGET_ARCH} signed-by=/etc/apt/trusted.gpg.d/docker.key.gpg] https://download.docker.com/linux/debian ${IB_SUITE} stable" > config/archives/docker.list

cat > config/archives/backports.pref << EOT
Package: *
Pin: release a=bullseye-backports
Pin-Priority: 900
EOT

# Dependencies

## Base dependencies
dpkg-deb --fsys-tarfile $base_dir/overlays/deb/embassyos_0.3.x-1_${IB_TARGET_ARCH}.deb | tar --to-stdout -xvf - ./usr/lib/embassy/depends > config/package-lists/embassy-depends.list.chroot

## Firmware
if [ "$NON_FREE" = 1 ]; then
  echo 'firmware-iwlwifi firmware-misc-nonfree firmware-brcm80211' > config/package-lists/nonfree.list.chroot
fi

if [ "${IB_TARGET_PLATFORM}" = "raspberrypi" ]; then
  echo 'raspberrypi-bootloader rpi-update parted' > config/package-lists/bootloader.list.chroot
else
  echo 'grub-efi grub2-common' > config/package-lists/bootloader.list.chroot
fi
if [ "${IB_TARGET_ARCH}" = "amd64" ] || [ "${IB_TARGET_ARCH}" = "i386" ]; then
  echo 'grub-pc-bin' >> config/package-lists/bootloader.list.chroot
fi

cat > config/hooks/normal/9000-install-startos.hook.chroot << EOF
#!/bin/bash

set -e

apt-get install -y /deb/embassyos_0.3.x-1_${IB_TARGET_ARCH}.deb
rm -rf /deb

if [ "${IB_TARGET_PLATFORM}" = "raspberrypi" ]; then
  update-initramfs -c -k 6.1.21-v8+
fi

echo start > /etc/hostname

cat > /etc/hosts << EOT
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOT

useradd --shell /bin/bash -G embassy -m start9
echo start9:embassy | chpasswd
usermod -aG sudo start9

echo "start9 ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/010_start9-nopasswd"

if [ "${IB_TARGET_PLATFORM}" != "raspberrypi" ]; then
  /usr/lib/embassy/scripts/enable-kiosk
fi

if ! [[ "${IB_OS_ENV}" =~ (^|-)dev($|-) ]]; then
  passwd -l start9
fi

rm /usr/local/bin/apt-get

EOF

cat > config/hooks/live/9000-grub-set-default.hook.binary << EOF
sed -i -e '1i set default=0' boot/grub/config.cfg
sed -i -e '2i set timeout=5' boot/grub/config.cfg
EOF

if [[ "$BOOTLOADERS" =~ isolinux ]]; then
cat > config/hooks/live/isolinux.hook.binary << EOF
sed -i 's|timeout 0|timeout 5|' isolinux/isolinux.cfg
EOF
fi

if [ "${IB_TARGET_PLATFORM}" = "raspberrypi" ]; then
  lb bootstrap
  lb chroot
  lb binary_chroot
  lb chroot_prep install devpts proc selinuxfs sysfs
  lb chroot_devpts install
  lb chroot_proc install
  lb chroot_selinuxfs install
  lb chroot_sysfs install
  lb chroot_prep install dpkg tmpfs sysv-rc hosts resolv hostname apt mode-apt-install-binary mode-archives-chroot
  lb chroot_dpkg install
  lb chroot_tmpfs install
  lb chroot_sysv-rc install
  lb chroot_hosts install
  lb chroot_resolv install
  lb chroot_hostname install
  lb chroot_apt install-binary
  lb chroot_archives chroot install
  lb binary_rootfs
  mv $prep_results_dir/binary/live/filesystem.squashfs $RESULTS_DIR/$IMAGE_BASENAME.squashfs
else
  lb build
  mv $prep_results_dir/binary/live/filesystem.squashfs $RESULTS_DIR/$IMAGE_BASENAME.squashfs
  mv $prep_results_dir/live-image-${IB_TARGET_ARCH}.hybrid.iso $RESULTS_DIR/$IMAGE_BASENAME.iso
fi