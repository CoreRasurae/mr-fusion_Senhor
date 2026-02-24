#!/bin/bash
# Copyright 2024 Michael Smith <m@hacktheplanet.be>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3 as published
# by the Free Software Foundation.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.

if [[ -z "${SENHOR_RELEASE}" ]]; then
  echo "Please set SENHOR_RELEASE environment variable to a valid release, e.g. 'release_Senhor_20231108.7z'"
  echo "See https://github.com/CoreRasurae/SD-Installer-Win64_Senhor/tree/master for a list of available releases."
  exit 1
fi

if [[ -z "${FUSION_FS_CONFIG}" ]]; then
  echo "Please set FUSION_FS_CONFIG environment variable to a valid root filesystem type, e.g. 'exfat' or 'ext4'"
  exit 1
fi

echo "Building SD card image with ${SENHOR_RELEASE}..."

# Create the SD card image container
dd if=/dev/zero of=/files/images/mr-fusion.img bs=16M count=10

# Partition the SD card image
sfdisk --force /files/images/mr-fusion.img << EOF
start=10240, type=0b
start=2048, size=8192, type=a2
EOF
sfdisk /files/images/mr-fusion.img -A 2 

# Attach the SD card image to a loopback device
LOOP_DEV=$( losetup -f )
echo "Using loop device: $LOOP_DEV"
losetup -P $LOOP_DEV /files/images/mr-fusion.img

# Install the bootloader
dd if="/files/vendor/bootloader.img" of="${LOOP_DEV}p2" bs=64k
sync

# Create the data partition
mkfs.vfat -n "MRFUSION" ${LOOP_DEV}p1
mkdir -p /mnt/data
mount ${LOOP_DEV}p1 /mnt/data

# Copy support files
cp -r /files/vendor/support/* /mnt/data/

# Copy kernel and initramfs
cp /home/mr-fusion/linux-socfpga/arch/arm/boot/zImage /mnt/data

# Set the configuration for the FS... for now only a single config
echo "FUSION_FS_CONFIG=${FUSION_FS_CONFIG}" > /mnt/data/build_configs.sh

# Download and copy MiSTer release.
curl -LsS -o /mnt/data/release.7z \
  https://github.com/CoreRasurae/SD-Installer-Win64_Senhor/raw/master/${SENHOR_RELEASE}

# Support MiSTer Scripts
mkdir -p /mnt/data/Scripts

# Bundle WiFi setup script with Mr. Fusion
curl -LsS -o /mnt/data/Scripts/wifi.sh \
  https://raw.githubusercontent.com/MiSTer-devel/Scripts_MiSTer/master/other_authors/wifi.sh

# Bundle SDL Game Controller database with Mr. Fusion
curl -LsS -o /mnt/data/gamecontrollerdb.txt \
  https://raw.githubusercontent.com/MiSTer-devel/Distribution_MiSTer/main/linux/gamecontrollerdb/gamecontrollerdb.txt

# Support custom MiSTer config
mkdir -p /mnt/data/config

# Clean up
sync
umount /mnt/data
losetup -d ${LOOP_DEV}

# Rename and compress the SD card image
cd /files/images
zip -m mr-fusion-${FUSION_FS_CONFIG}_$(date +"%Y-%m-%d").img.zip mr-fusion.img
