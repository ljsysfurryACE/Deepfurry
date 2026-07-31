#!/bin/bash
# Deepfurry CI 构建脚本
set -e
cd /tmp
echo "=== CI 环境诊断 === "
echo "WS=$WS GITHUB_WORKSPACE=$GITHUB_WORKSPACE"
echo "whoami=$(whoami) PWD=$PWD"
ls -la ${WS:-$GITHUB_WORKSPACE}/ 2>&1 | head -10

echo "=== [1/4] 下载并编译内核 ==="
mkdir -p /tmp/build
cd /tmp/build
echo "从软件源下载内核源码 (130MB)..."
curl -sL --connect-timeout 30 --max-time 900 "https://furryhifurry.space/deep-repo/linux-7.1.5.tar.xz" -o linux.tar.xz
ls -la linux.tar.xz
tar xf linux.tar.xz
cd linux-7.1.5
echo "内核源码就绪"
if [ -f ${WS:-${GITHUB_WORKSPACE}}/kernel_config ]; then
    cp ${WS:-${GITHUB_WORKSPACE}}/kernel_config .config
else
    make defconfig
fi
./scripts/config -e CONFIG_WLAN
./scripts/config -e CONFIG_WIRELESS
./scripts/config -e CONFIG_CFG80211
./scripts/config -e CONFIG_MAC80211
./scripts/config --set-str CONFIG_INITRAMFS_SOURCE ""
make olddefconfig
make -j$(nproc) bzImage
cp arch/x86/boot/bzImage /tmp/bzImage
echo "✅ 内核编译完成"

echo "=== [2/4] 构建 initramfs ==="
mkdir -p /tmp/initramfs/{bin,usr/bin,etc,proc,sys,tmp,root,dev,var/log,www}
cd /tmp/initramfs
# busybox (静态)
if ! curl -sL --connect-timeout 15 "https://busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox" -o bin/busybox 2>/dev/null || [ ! -s bin/busybox ]; then
    apt-get install -y -qq busybox-static
    cp /bin/busybox bin/busybox
fi
chmod +x bin/busybox
# 预编译工具 (从软件源)
mkdir -p /tmp/deep-repo/packages
for pkg in dialog htop iw wpasupplicant nano; do
    mkdir -p /tmp/deep-repo/packages/$pkg
    curl -sL --connect-timeout 15 "https://furryhifurry.space/deep-repo/packages/$pkg/$pkg" -o /tmp/deep-repo/packages/$pkg/$pkg 2>/dev/null || true
    [ -s /tmp/deep-repo/packages/$pkg/$pkg ] && cp /tmp/deep-repo/packages/$pkg/$pkg usr/bin/ 2>/dev/null
done
# init 脚本
cp ${WS:-${GITHUB_WORKSPACE}}/init.sh init 2>/dev/null || echo '#!/bin/busybox sh
/bin/busybox mount -t proc none /proc 2>/dev/null
/bin/busybox mount -t sysfs none /sys 2>/dev/null
exec /bin/sh' > init
chmod +x init
# deep 包管理器
[ -f ${WS:-${GITHUB_WORKSPACE}}/deep ] && cp ${WS:-${GITHUB_WORKSPACE}}/deep bin/deep && chmod +x bin/deep
# 打包
find . | cpio -H newc -o 2>/dev/null | gzip > /tmp/initramfs.gz
echo "✅ initramfs 完成 ($(du -h /tmp/initramfs.gz | cut -f1))"

echo "=== [3/4] 构建 UEFI 镜像 ==="
cd ${WS:-${GITHUB_WORKSPACE}}
IMG=deepfurry_v8.2.img
dd if=/dev/zero of=$IMG bs=1M count=64 2>/dev/null
parted -s $IMG mklabel gpt
parted -s $IMG mkpart primary fat32 1MiB 63MiB
parted -s $IMG set 1 esp on
LOOP=$(losetup -Pf --show $IMG)
mkfs.vfat -F32 -n DEEPFURRY ${LOOP}p1
mkdir -p /tmp/mnt
mount ${LOOP}p1 /tmp/mnt
mkdir -p /tmp/mnt/EFI/BOOT /tmp/mnt/boot/grub
grub-mkimage -o /tmp/mnt/EFI/BOOT/BOOTX64.EFI -O x86_64-efi -p /EFI/BOOT \
    fat ext2 part_gpt normal boot linux configfile loopback search help
cp /tmp/bzImage /tmp/mnt/boot/vmlinuz
cp /tmp/initramfs.gz /tmp/mnt/boot/initrd.img
cat > /tmp/grub.cfg << 'GRUBEOF'
set timeout=3
set default=0
menuentry "🐾 Deepfurry 7.1.5 (v8.2)" {
    linux /boot/vmlinuz console=ttyS0,115200 quiet
    initrd /boot/initrd.img
}
GRUBEOF
cp /tmp/grub.cfg /tmp/mnt/EFI/BOOT/grub.cfg
cp /tmp/grub.cfg /tmp/mnt/boot/grub/grub.cfg
sync
umount /tmp/mnt
losetup -d $LOOP
ls -lh $IMG
echo "✅ 镜像构建完成"

echo "=== [4/4] QEMU 启动验证 ==="
cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/ovmf_vars.fd 2>/dev/null || true
timeout 150 qemu-system-x86_64 -machine q35,accel=tcg -m 512 -smp 2 \
    -drive file=$IMG,format=raw,if=none,id=disk0 \
    -device ide-hd,drive=disk0,bus=ide.0 \
    -drive file=/usr/share/OVMF/OVMF_CODE_4M.fd,if=pflash,format=raw,readonly=on \
    -drive file=/tmp/ovmf_vars.fd,if=pflash,format=raw \
    -nographic -no-reboot -serial mon:stdio > /tmp/qemu.log 2>&1 &
QEMU_PID=$!
for i in $(seq 1 30); do
    sleep 5
    if grep -q "BusyBox v" /tmp/qemu.log 2>/dev/null; then
        echo "✅ QEMU 验证通过: 系统启动到 shell"
        kill $QEMU_PID 2>/dev/null
        exit 0
    fi
done
echo "❌ QEMU 验证失败"
tail -30 /tmp/qemu.log
kill $QEMU_PID 2>/dev/null
exit 1
