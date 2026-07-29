# 构建信息

## 源码来源
- Linux 内核: https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.5.tar.xz
- BusyBox: https://busybox.net/downloads/busybox-1.37.0.tar.bz2 (未使用, 偷懒用系统自带)
- musl libc: https://musl.libc.org/releases/musl-1.2.5.tar.gz (未使用)

## 编译命令
```bash
# 内核
make defconfig
make -j4 bzImage

# initramfs C init
gcc -static -Os -o init mininit.c

# GRUB
grub-mkimage -o BOOTX64.EFI -O x86_64-efi
```

## 踩坑列表
1. dpkg 损坏导致 apt 不可用
2. kernel.org CDN 下载极慢 (15KB/s)
3. defconfig 编译需要 2-3 小时
4. EFI_STUB 编出的内核无 PE 头, 不能用直启
5. initramfs shell 脚本找不到 /dev/console
6. 串口无输出需传 console=ttyS0
7. BusyBox kconfig 交互式卡住
8. 64MB 内存 OOM
