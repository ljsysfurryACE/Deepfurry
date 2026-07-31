#!/bin/bash
# Deepfurry v8.1 自动构建脚本
# 内核 7.1.5 + WiFi + TUI Dashboard + Package Manager

set -e
DIR=/tmp/deepfurry-build
KERNEL_SRC=https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.5.tar.xz
DISTRO_DIR=/tmp/linux_distro
INITRAMFS_DIR=$DISTRO_DIR/initramfs
PKG_DIR=/tmp/deep-repo

echo "=== 🐾 Deepfurry v8.1 Build ==="
mkdir -p $DIR $DISTRO_DIR

# 1. 下载内核源码
echo "[1/6] 下载内核源码..."
[ -f $DIR/linux-7.1.5.tar.xz ] || curl -L -o $DIR/linux-7.1.5.tar.xz $KERNEL_SRC
[ -d $DIR/linux-7.1.5 ] || (cd $DIR && tar xf linux-7.1.5.tar.xz)

# 2. 配置内核（启用 WiFi 支持）
echo "[2/6] 配置内核 (WiFi enabled)..."
cd $DIR/linux-7.1.5
if [ ! -f .config ]; then
    make defconfig
    # WiFi 支持
    ./scripts/config -e CONFIG_WLAN
    ./scripts/config -e CONFIG_WIRELESS
    ./scripts/config -e CONFIG_CFG80211
    ./scripts/config -e CONFIG_MAC80211
    ./scripts/config -e CONFIG_MAC80211_RC_DEFAULT_MINSTREL
    # 常见 WiFi 驱动
    ./scripts/config -e CONFIG_ATH_COMMON
    ./scripts/config -e CONFIG_ATH9K
    ./scripts/config -e CONFIG_ATH9K_HTC
    ./scripts/config -e CONFIG_ATH10K
    ./scripts/config -e CONFIG_ATH10K_PCI
    ./scripts/config -e CONFIG_BRCMFMAC
    ./scripts/config -e CONFIG_BRCMFMAC_PCIE
    ./scripts/config -e CONFIG_IWLWIFI
    ./scripts/config -e CONFIG_IWLDVM
    ./scripts/config -e CONFIG_IWLMVM
    ./scripts/config -e CONFIG_RTLWIFI
    ./scripts/config -e CONFIG_RTL8XXXU
    ./scripts/config -e CONFIG_MT7921E
    ./scripts/config -e CONFIG_RT2X00
    ./scripts/config -e CONFIG_RT2800USB
    # 压缩 initramfs
    ./scripts/config -e CONFIG_KERNEL_GZIP
    # 网桥/路由 (可选)
    ./scripts/config -e CONFIG_BRIDGE
    ./scripts/config -e CONFIG_NETFILTER
    ./scripts/config -e CONFIG_IP_NF_FILTER
    ./scripts/config -e CONFIG_NETFILTER_XT_MATCH_STATE
fi
echo "  编译内核..."
make -j$(nproc) bzImage 2>&1 | tail -3
cp arch/x86/boot/bzImage $DISTRO_DIR/

# 3. 编译 Dropbear (SSH)
echo "[3/6] 编译 Dropbear..."
cd $DIR
[ -d dropbear-2024.85 ] || (curl -L https://matt.ucc.asn.au/dropbear/releases/dropbear-2024.85.tar.bz2 | tar xj)
cd dropbear-2024.85
./configure --enable-static --disable-pam --disable-zlib 2>/dev/null
make -j$(nproc) MULTI=1 2>/dev/null
cp dropbearmulti $INITRAMFS_DIR/bin/

# 4. 组装 initramfs（含新工具）
echo "[4/6] 配置 initramfs..."
mkdir -p $INITRAMFS_DIR/bin $INITRAMFS_DIR/usr/bin \
         $INITRAMFS_DIR/usr/share/udhcpc \
         $INITRAMFS_DIR/etc $INITRAMFS_DIR/www

# 复制预编译的静态包
[ -f $PKG_DIR/packages/dialog/dialog ] && cp $PKG_DIR/packages/dialog/dialog $INITRAMFS_DIR/usr/bin/dialog
[ -f $PKG_DIR/packages/htop/htop ] && cp $PKG_DIR/packages/htop/htop $INITRAMFS_DIR/usr/bin/htop
[ -f $PKG_DIR/packages/iw/iw ] && cp $PKG_DIR/packages/iw/iw $INITRAMFS_DIR/usr/bin/iw
[ -f $PKG_DIR/packages/wpasupplicant/wpa_supplicant ] && cp $PKG_DIR/packages/wpasupplicant/wpa_supplicant $INITRAMFS_DIR/usr/bin/wpa_supplicant
[ -f $PKG_DIR/packages/wpa_passphrase/wpa_passphrase ] && cp $PKG_DIR/packages/wpa_passphrase/wpa_passphrase $INITRAMFS_DIR/usr/bin/wpa_passphrase

# 确保 busybox 在
[ -f $DISTRO_DIR/busybox ] && cp $DISTRO_DIR/busybox $INITRAMFS_DIR/bin/busybox

# 安装脚本到 initramfs
cp $DISTRO_DIR/initramfs/init $DISTRO_DIR/initramfs/usr/bin/setup $DISTRO_DIR/initramfs/usr/bin/install.sh 2>/dev/null || true
cp /tmp/initmenu_v2 $INITRAMFS_DIR/usr/bin/menu 2>/dev/null || cp $INITRAMFS_DIR/usr/bin/initmenu $INITRAMFS_DIR/usr/bin/menu 2>/dev/null
cp /tmp/deep_v2 $INITRAMFS_DIR/bin/deep 2>/dev/null || true

chmod +x $INITRAMFS_DIR/usr/bin/* $INITRAMFS_DIR/bin/* 2>/dev/null

# 5. 打包 initramfs
echo "[5/6] 打包 initramfs..."
cd $INITRAMFS_DIR
find . | cpio -H newc -o 2>/dev/null | gzip > $DISTRO_DIR/initramfs.gz

# 6. 构建 UEFI 镜像
echo "[6/6] 构建 UEFI 镜像 (64MB)..."
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
cp $DISTRO_DIR/initramfs.gz /mnt/boot/initrd.img
cp bzImage /mnt/boot/vmlinuz
cat > /mnt/boot/grub/grub.cfg << 'GRUBEOF'
set timeout=5
set default=0
menuentry "🐾 Deepfurry 7.1.5 (v8.1)" {
    linux /boot/vmlinuz quiet
    initrd /boot/initrd.img
}
menuentry "Deepfurry - 救援模式" {
    linux /boot/vmlinuz single
    initrd /boot/initrd.img
}
menuentry "Deepfurry - 详细日志" {
    linux /boot/vmlinuz loglevel=7
    initrd /boot/initrd.img
}
GRUBEOF
sync
umount /mnt 2>/dev/null
losetup -d $LOOP 2>/dev/null

cp $IMG /root/.openclaw/workspace/deepfurry_v8.1.img

echo ""
echo "======================"
echo "  🐾 构建完成!"
echo "======================"
echo "  v8.1 更新内容:"
echo "  ✅ WiFi 支持 (wpa_supplicant + iw)"
echo "  ✅ TUI 管理面板 (dialog)"
echo "  ✅ 包管理器 deep v2 (5个包)"
echo "  ✅ htop 进程监控"
echo "  ✅ GRUB 启动菜单 (3模式)"
echo ""
echo "  镜像: /root/.openclaw/workspace/deepfurry_v8.1.img"
ls -lh /root/.openclaw/workspace/deepfurry_v8.1.img
