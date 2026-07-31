#!/bin/bash
# Cloud LTE OS CI 验证脚本: 下载成品镜像 + 结构校验 + QEMU 冒烟测试
set -e
cd /tmp

echo "=== [1/3] 下载 Cloud LTE OS v8.2 镜像 ==="
# 从软件源下载最新镜像 (HK 服务器)
curl -sL --connect-timeout 30 --max-time 300 "https://furryhifurry.space/deep-repo/cloudlte/cloudlte_v8.2.img" -o /tmp/cloudlte_v8.2.img 2>/dev/null || \
curl -sL --connect-timeout 30 --max-time 300 "https://github.com/ljsysfurryACE/Cloud LTE OS/releases/latest/download/cloudlte_v8.2.img" -o /tmp/cloudlte_v8.2.img 2>/dev/null
if [ ! -s /tmp/cloudlte_v8.2.img ]; then
    echo "❌ 镜像下载失败，尝试从仓库构建..."
    # fallback: 如果仓库里有镜像文件直接用
    if [ -f ${WS:-$GITHUB_WORKSPACE}/cloudlte_v8.2.img ]; then
        cp ${WS:-$GITHUB_WORKSPACE}/cloudlte_v8.2.img /tmp/cloudlte_v8.2.img
    else
        exit 1
    fi
fi
ls -lh /tmp/cloudlte_v8.2.img

echo "=== [2/3] 镜像结构校验 ==="
IMG=/tmp/cloudlte_v8.2.img
LOOP=$(losetup -Pf --show $IMG)
partprobe $LOOP
sleep 1
mkdir -p /tmp/mnt
mount ${LOOP}p1 /tmp/mnt
echo "--- 分区内容 ---"
ls -la /tmp/mnt/boot/
echo "--- 校验关键文件 ---"
[ -f /tmp/mnt/EFI/BOOT/BOOTX64.EFI ] && echo "✅ EFI 引导文件存在" || echo "❌ 缺 EFI"
[ -f /tmp/mnt/boot/vmlinuz ] && echo "✅ 内核存在 ($(stat -c%s /tmp/mnt/boot/vmlinuz) bytes)" || echo "❌ 缺内核"
[ -f /tmp/mnt/boot/initrd.img ] && echo "✅ initrd 存在 ($(stat -c%s /tmp/mnt/boot/initrd.img) bytes)" || echo "❌ 缺 initrd"
echo "--- initrd 内工具检查 ---"
cd /tmp && rm -rf /tmp/initrd_chk && mkdir /tmp/initrd_chk
cd /tmp/initrd_chk && gunzip -c /tmp/mnt/boot/initrd.img > initrd.cpio
for tool in nano sqlite3 tcpdump htop dialog iw menu deep; do
    if cpio -it < initrd.cpio 2>/dev/null | grep -qE "usr/bin/$tool$|bin/$tool$"; then
        echo "  ✅ $tool"
    else
        echo "  ⚠️  $tool 缺失"
    fi
done
umount /tmp/mnt
losetup -d $LOOP

echo "=== [3/3] QEMU 冒烟测试 ==="
# 检查 OVMF 可用性
if [ -f /usr/share/OVMF/OVMF_CODE_4M.fd ]; then
    cp /usr/share/OVMF/OVMF_VARS_4M.fd /tmp/ovmf_vars.fd
    OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
elif [ -f /usr/share/ovmf/OVMF_CODE.fd ]; then
    cp /usr/share/ovmf/OVMF_VARS.fd /tmp/ovmf_vars.fd 2>/dev/null || dd if=/dev/zero of=/tmp/ovmf_vars.fd bs=1M count=4
    OVMF_CODE=/usr/share/ovmf/OVMF_CODE.fd
else
    echo "⚠️ 无 OVMF，跳过 QEMU 测试"
    exit 0
fi
# 启动并等待 shell 出现
timeout 180 qemu-system-x86_64 -machine q35,accel=tcg -m 512 -smp 2 \
    -drive file=/tmp/cloudlte_v8.2.img,format=raw,if=none,id=disk0 \
    -device ide-hd,drive=disk0,bus=ide.0 \
    -drive file=$OVMF_CODE,if=pflash,format=raw,readonly=on \
    -drive file=/tmp/ovmf_vars.fd,if=pflash,format=raw \
    -nographic -no-reboot -serial mon:stdio > /tmp/qemu.log 2>&1 &
QEMU_PID=$!
for i in $(seq 1 30); do
    sleep 6
    if grep -q "BusyBox v" /tmp/qemu.log 2>/dev/null; then
        echo "✅ QEMU 冒烟测试通过: 系统启动到 shell"
        kill $QEMU_PID 2>/dev/null
        exit 0
    fi
done
echo "❌ QEMU 冒烟测试失败"
tail -20 /tmp/qemu.log
kill $QEMU_PID 2>/dev/null
exit 1
