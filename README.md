# Deepfurry 7.1.5

从零编译的 Linux 命令行发行版。在 RainYun 4核3.8GB VPS 上纯手工编译。

## 规格

- 内核: Linux 7.1.5 x86_64 (3.9MB bzImage)
- 配置: defconfig, 794项驱动全开
- 根文件系统: BusyBox 1.36.1 静态编译, 272命令
- 引导: UEFI + GRUB 2.12, GPT分区表, FAT32 ESP
- 镜像大小: 64MB
- 最低内存: 128MB

## v2 新增

- ✅ Dropbear SSH 服务器（启动后自动运行，端口22）
- ✅ DHCP 自动获取IP
- ✅ 主机名: deepfurry

## 使用方法

```bash
# 写U盘
dd if=deepfurry_uefi_v2.img of=/dev/sdX bs=1M
```

UEFI 启动 → GRUB 菜单 → Deepfurry → Shell

## 文件说明

- `deepfurry_uefi_v2.img` — UEFI可启动镜像 (64MB, 含SSH+DHCP)
- `deepfurry_uefi_v1.img` — v1基础镜像 (64MB, 无网络)
- `initrd.img` — initramfs根文件系统
- `kernel_config` — Linux内核编译配置
- `deepfurry.html` — 项目介绍页

## 构建环境

- VPS: RainYun 4核, 3.8GB RAM
- 内核源码: kernel.org linux-7.1.5
- Dropbear: 2024.85 (静态编译)
- GCC: Ubuntu 13.3.0
