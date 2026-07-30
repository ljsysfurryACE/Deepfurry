#!/bin/bash
# Deepfurry 自动构建脚本
# 一次编译，全部打包

set -e
DIR=/tmp/deepfurry-build
KERNEL_SRC=https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.5.tar.xz
DISTRO_DIR=/tmp/linux_distro
INITRAMFS_DIR=$DISTRO_DIR/initramfs

echo "=== Deepfurry Build Script ==="
mkdir -p $DIR

# 1. 下载内核源码
echo "[1/5] 下载内核源码..."
[ -f $DIR/linux-7.1.5.tar.xz ] || curl -L -o $DIR/linux-7.1.5.tar.xz $KERNEL_SRC
[ -d $DIR/linux-7.1.5 ] || (cd $DIR && tar xf linux-7.1.5.tar.xz)

# 2. 编译内核
echo "[2/5] 编译内核..."
cd $DIR/linux-7.1.5
[ -f .config ] || make defconfig
make -j$(nproc) bzImage
cp arch/x86/boot/bzImage $DISTRO_DIR/

# 3. 编译 Dropbear
echo "[3/5] 编译 Dropbear..."
cd $DIR
[ -d dropbear-2024.85 ] || (curl -L https://matt.ucc.asn.au/dropbear/releases/dropbear-2024.85.tar.bz2 | tar xj)
cd dropbear-2024.85
./configure --enable-static --disable-pam --disable-zlib 2>/dev/null
make -j$(nproc) MULTI=1 2>/dev/null
cp dropbearmulti $INITRAMFS_DIR/bin/

# 4. 打包 initramfs
echo "[4/5] 打包 initramfs..."
cd $INITRAMFS_DIR && find . | cpio -H newc -o 2>/dev/null | gzip > $DISTRO_DIR/initramfs.gz

# 5. 构建 UEFI 镜像
echo "[5/5] 构建 UEFI 镜像..."
cd $DISTRO_DIR
IMG=deepfurry_uefi.img
rm -f $IMG
dd if=/dev/zero of=$IMG bs=1M count=64 2>/dev/null
parted -s $IMG mklabel gpt 2>/dev/null
parted -s $IMG mkpart primary fat32 1MiB 63MiB 2>/dev/null
parted -s $IMG set 1 esp on 2>/dev/null

LOOP=$(losetup -Pf --show $IMG 2>/dev/null)
mkfs.vfat -F32 -n DEEPFURRY ${LOOP}p1 2>/dev/null
mount ${LOOP}p1 /mnt 2>/dev/null
mkdir -p /mnt/EFI/BOOT /mnt/boot/grub
grub-mkimage -o /mnt/EFI/BOOT/BOOTX64.EFI -O x86_64-efi -p /EFI/BOOT \
  fat ext2 part_gpt normal boot linux configfile loopback search help 2>/dev/null
cp $INITRAMFS_DIR/../initramfs.gz /mnt/boot/initrd.img
cp bzImage /mnt/boot/vmlinuz
cp $INITRAMFS_DIR/../grub.cfg /mnt/boot/grub/ 2>/dev/null
sync
umount /mnt 2>/dev/null
losetup -d $LOOP 2>/dev/null
cp $IMG /root/.openclaw/workspace/

echo "=== 构建完成! ==="
echo "镜像: /root/.openclaw/workspace/$IMG"
ls -lh /root/.openclaw/workspace/$IMG
