#!/bin/busybox sh
# Deepfurry 7.1.5 v8.2 init
/bin/busybox mount -t proc none /proc
/bin/busybox mount -t sysfs none /sys
/bin/busybox mount -t devtmpfs none /dev
/bin/busybox mount -t tmpfs none /tmp
/bin/busybox --install -s

# 确保关键目录存在
mkdir -p /proc /sys /dev /tmp /root /etc /usr/bin /var/log /var/cache/deep 2>/dev/null
/bin/busybox mount -t proc none /proc 2>/dev/null
/bin/busybox mount -t sysfs none /sys 2>/dev/null
/bin/busybox mount -t devtmpfs none /dev 2>/dev/null
/bin/busybox mount -t tmpfs none /tmp 2>/dev/null

# Console
for tty in /dev/ttyS0 /dev/tty1 /dev/console; do
    [ -c "$tty" ] && exec < "$tty" > "$tty" 2>&1 && break
done

# ===== 系统稳定性 =====
# 1. swap 文件 (64MB, 防止 OOM)
if [ ! -f /swapfile ]; then
    dd if=/dev/zero of=/swapfile bs=1M count=64 2>/dev/null
    chmod 600 /swapfile
    mkswap /swapfile 2>/dev/null
    swapon /swapfile 2>/dev/null && echo "  ✅ swap 已启用 (64MB)"
fi

# 2. 日志轮转 (防止 /var/log 写满)
echo "0 3 * * *  find /var/log -type f -size +1M -exec truncate -s 1M {} \\; 2>/dev/null" >> /etc/crontabs/root 2>/dev/null || true
echo "0 6 * * *  echo -n > /var/log/*.log 2>/dev/null" >> /etc/crontabs/root 2>/dev/null || true
crond 2>/dev/null &

# 3. 清理临时文件
rm -rf /tmp/* 2>/dev/null

# Start networking (eth0 DHCP)
udhcpc -i eth0 -q -s /usr/share/udhcpc/default.script 2>/dev/null &

# Welcome screen
clear
echo ""
echo "  ======================================="
echo "   🐾 Deepfurry 7.1.5 v8.2"
echo "   Linux from Scratch"
echo "   WiFi + TUI + Swap + Logrotate"
echo "  ======================================="
echo ""
echo "  Commands:"
echo "    menu    - 系统管理面板"
echo "    deep    - 包管理器"
echo "    shell   - 命令行"
echo ""

# 检查是不是交互终端
if [ -t 0 ] && [ -t 1 ]; then
    echo -n "自动启动菜单 (3)..."
    for i in 3 2 1; do
        printf "\b\b\b\b\b\b\b\b\b\b\b\b(%ds)  " $i
        read -t 1 KEY 2>/dev/null && break
    done
    echo ""
    [ "$KEY" = "shell" ] && exec /bin/sh
    [ "$KEY" != "menu" ] && /usr/bin/menu 2>/dev/null
fi

echo "进入 shell (输入 menu 打开面板)"
exec /bin/sh
