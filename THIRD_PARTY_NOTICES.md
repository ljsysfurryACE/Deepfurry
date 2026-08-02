# Third-Party Notices

Cloud LTE OS 包含以下第三方组件，各组件遵循其上游许可证。本文件提供完整声明；GPL/LGPL 组件的对应源码获取方式见文末。

## 镜像内组件

| 组件 | 版本 | 许可证 | 用途 |
|------|------|--------|------|
| Linux 内核 | 7.1.5 | GPL-2.0-only | 操作系统内核（含 KASLR/网络栈/驱动） |
| BusyBox | 1.36.1 | GPL-2.0-only | 核心命令行工具集 |
| dialog | 1.3 | LGPL-2.1-or-later | TUI 界面框架 |
| htop | 3.3.0 | GPL-3.0-or-later | 进程监控 |
| iw | 6.7 | ISC | WiFi 配置工具 |
| wpa_supplicant | 2.11 | BSD-3-Clause | WiFi 连接 |
| musl | 1.2.5 | MIT | 用户态 C 库运行时 |
| nano | 8.2 | GPL-3.0-or-later | 文本编辑器 |
| sqlite3 | 3.45.3 | Public Domain | 轻量数据库 |
| tcpdump | 4.99.4 | BSD-3-Clause | 网络抓包 |
| zlib | — | zlib License | 压缩库（stbi 依赖） |
| stb_image | — | MIT OR Unlicense | 图片解码 |
| stb_truetype | — | MIT OR Unlicense | 字体渲染 |
| dr_mp3 | — | MIT-0 OR Unlicense | MP3 解码 |

## 仓库工具脚本

| 脚本 | 说明 |
|------|------|
| build.sh / ci_build.sh | 构建与 CI 脚本（本项目原创） |
| deep | 包管理器（本项目原创） |
| init.sh / menu.sh | 系统启动与菜单脚本（本项目原创） |

## GPL 组件源码获取

本系统镜像中使用的 GPL-2.0 组件（Linux 内核、BusyBox）的完整对应源码可通过以下途径获取：

1. **Linux 内核 7.1.5 源码**：
   - https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.1.5.tar.xz
   - 或 https://github.com/torvalds/linux （tag: v7.1）

2. **BusyBox 1.36.1 源码**：
   - https://busybox.net/downloads/busybox-1.36.1.tar.bz2

3. 内核编译配置（.config）见仓库 `kernel_config` 文件。

本项目构建脚本 `build.sh` 包含从源码构建内核与 BusyBox 的完整步骤，可复现对应二进制。

## 联系我们

- 项目仓库：https://github.com/ljsysfurryACE/Deepfurry
- 软件源：https://furryhifurry.space/deep-repo/

*本文件由 Cloud LTE OS 项目组维护，随系统镜像与仓库源码分发。*
