# ☁️ Cloud LTE OS — Linux from Scratch

**Cloud LTE OS** 从零编译的微型 Linux 发行版，基于 Linux 7.1.5 内核 + BusyBox。

## v8.2 新特性

| 功能 | 说明 |
|------|------|
| ✅ **WiFi 支持** | wpa_supplicant + iw，支持 WPA2/WPA3 无线网络 |
| ✅ **TUI 管理面板** | dialog 驱动的系统仪表盘（后退到纯 Shell） |
| ✅ **包管理器 v2** | `deep install/remove/list/update/search` |
| ✅ **htop** | 交互式进程监控 |
| ✅ **GRUB 启动菜单** | 正常 / 救援 / 详细日志 三种模式 |
| ✅ **软件源** | 5 个包可安装 |

## 系统规格

- **内核:** Linux 7.1.5 (x86_64)
- **大小:** 64MB
- **init:** BusyBox Shell
- **SSH:** Dropbear
- **包管理器:** deep
- **软件源:** deep-repo

## 下载

| 文件 | 大小 | 说明 |
|------|------|------|
| `cloudlte_v8.2.img` | 64MB | UEFI 启动镜像 |
| `cloudlte-7.1.5-v8.2-installer.iso` | 18MB | 安装 ISO（BIOS/UEFI 双启） |
| `build.sh` | — | 自动构建脚本 |

## 启动

```bash
# 写入 U 盘
dd if=cloudlte_v8.2.img of=/dev/sdX bs=1M

# 或 QEMU 测试（推荐 KVM 加速）
qemu-system-x86_64 -machine q35,accel=kvm -m 512 \
  -drive file=cloudlte_v8.2.img,format=raw,if=none,id=disk0 \
  -device ide-hd,drive=disk0,bus=ide.0 \
  -drive file=/usr/share/OVMF/OVMF_CODE_4M.fd,if=pflash,format=raw,readonly=on
```

> **⚠️ 注意：** 纯软件模拟（TCG）启动较慢且 CPU 占用高，建议使用 KVM。
> 无 KVM 的环境可加 `-accel tcg -smp 2 -m 384` 运行，等待时间会长一些。

## 已验证的启动链（QEMU 实测）

通过 QEMU + OVMF (UEFI) 实测确认以下启动环节全部正常：

| 阶段 | 状态 |
|------|------|
| UEFI 固件 | ✅ BdsDxe 正常加载 |
| GRUB 菜单 | ✅ 3 个启动项正常渲染 |
| 内核加载 | ✅ Linux 7.1.5 #1 启动 |
| initramfs 解压 | ✅ init 脚本执行 |
| init 运行 | ✅ PID 1 正常（menu 失败回退 shell） |

### 测试方法

```bash
# 需要 OVMF (UEFI 固件)
# Debian/Ubuntu: apt install ovmf

qemu-system-x86_64 -machine q35,accel=kvm -m 512 \
  -drive file=cloudlte_v8.2.img,format=raw,if=none,id=disk0 \
  -device ide-hd,drive=disk0,bus=ide.0 \
  -drive file=/usr/share/OVMF/OVMF_CODE_4M.fd,if=pflash,format=raw,readonly=on \
  -drive file=OVMF_VARS_4M.fd,if=pflash,format=raw \
  -nographic -serial mon:stdio
```

### 排错

- **GRUB 停在 grub> 提示符**：确保 grub.cfg 同时存在于 `EFI/BOOT/grub.cfg`（GRUB prefix 目录）
- **盲启动无输出**：内核启动参数需带 `console=ttyS0,115200`（串口输出）
- **Kernel panic: Attempted to kill init**：init 脚本不能 `exec` 会退出的程序，应回退到 shell

## 用法

```
deep update        # 刷新包列表
deep install htop  # 安装 htop
deep list          # 查看已安装
menu               # 打开管理面板
```

## 许可证

本项目（脚本与构建工具）采用 **GPL-3.0 License**，见 [LICENSE](./LICENSE)。

系统镜像内的第三方组件（Linux 内核、BusyBox 等）遵循各自的上游许可证，完整声明见 [THIRD_PARTY_NOTICES.md](./THIRD_PARTY_NOTICES.md)。GPL 组件的对应源码获取方式已在其中说明。
