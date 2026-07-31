#!/bin/busybox sh
# Deepfurry 7.1.5 v8.1 init
/bin/busybox mount -t proc none /proc
/bin/busybox mount -t sysfs none /sys
/bin/busybox mount -t devtmpfs none /dev
/bin/busybox mount -t tmpfs none /tmp
/bin/busybox --install -s

# Console
for tty in /dev/ttyS0 /dev/tty1 /dev/console; do
    [ -c "$tty" ] && exec < "$tty" > "$tty" 2>&1 && break
done

# Start networking (eth0 DHCP)
udhcpc -i eth0 -q -s /usr/share/udhcpc/default.script 2>/dev/null &

# Welcome screen
clear
echo ""
echo "  ╔═══════════════════════════════════╗"
echo "  ║   🐾 Deepfurry 7.1.5 v8.1        ║"
echo "  ║   Linux from Scratch              ║"
echo "  ╠═══════════════════════════════════╣"
echo "  ║  WiFi, TUI Dashboard, Packages    ║"
echo "  ╚═══════════════════════════════════╝"
echo ""
echo "  Commands:"
echo "    menu    - 系统管理面板"
echo "    deep    - 包管理器"
echo "    shell   - 命令行"
echo ""

# Auto-start menu if dialog is available
if [ -f /usr/bin/dialog ]; then
    echo -n "自动启动菜单 (3)..."
    for i in 3 2 1; do
        printf "\b\b\b\b\b\b\b\b\b\b\b\b(%ds)  " $i
        read -t 1 KEY 2>/dev/null && break
    done
    echo ""
    [ "$KEY" != "shell" ] && exec /usr/bin/menu
fi

[ "$KEY" = "menu" ] && exec /usr/bin/menu
exec /bin/sh
