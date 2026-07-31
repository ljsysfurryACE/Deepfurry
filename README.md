# 🐾 Deepfurry — Linux from Scratch

**Deepfurry** 从零编译的微型 Linux 发行版，基于 Linux 7.1.5 内核 + BusyBox。

## v8.1 新特性

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
| `deepfurry_v8.1.img` | 64MB | UEFI 启动镜像 |
| `build.sh` | — | 自动构建脚本 |

## 启动

```bash
# 写入 U 盘
dd if=deepfurry_v8.1.img of=/dev/sdX bs=1M

# 或 QEMU 测试
qemu-system-x86_64 -drive file=deepfurry_v8.1.img,format=raw -m 512
```

## 用法

```
deep update        # 刷新包列表
deep install htop  # 安装 htop
deep list          # 查看已安装
menu               # 打开管理面板
```
