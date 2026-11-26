#!/bin/bash
# =============================================================================
# fnOS 1.2.1011 / K20 Pro (raphael, SM8150) 线刷脚本 (Linux / macOS)
# 流程：fastboot 刷 boot -> 重启 -> adb root -> 定位根分区(fnos 优先, sda35 兜底)
#       -> 格式化 ext4 -> 解压 rootfs -> 叠加 overlay -> 重启
# 注意：根分区数据会被清除。手机需已解锁 Bootloader。
# =============================================================================
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
BOOT="$DIR/boot_fnos_k20pro.img"
ROOTFS="$DIR/rootfs.tar.gz"
OVERLAY="$DIR/overlay.tar.gz"
DEVSH="$DIR/device-flash-rootfs.sh"

echo "======================================"
echo " fnOS K20 Pro 线刷 (fastboot + adb) "
echo "======================================"

for f in "$BOOT" "$ROOTFS" "$DEVSH"; do
    [ -f "$f" ] || { echo "错误：缺少 $f"; exit 1; }
done

echo "[1/4] 检查 fastboot 设备 ..."
fastboot devices || { echo "未检测到 fastboot 设备，请进入 fastboot 模式"; exit 1; }

read -p "确认刷写 boot 与根分区，根分区数据将被清除！输入 y 继续：" ans
[ "$ans" = "y" ] || { echo "已取消"; exit 0; }

echo "[2/4] fastboot 刷写 boot 分区 ..."
fastboot flash boot "$BOOT"

echo "[3/4] 重启设备并等待 adb ..."
fastboot reboot || true
sleep 6
adb wait-for-device
adb root 2>/dev/null || true
sleep 3

echo "[4/4] 推送 rootfs / overlay / 设备端脚本 ..."
adb push "$ROOTFS" /data/local/tmp/rootfs.tar.gz
[ -f "$OVERLAY" ] && adb push "$OVERLAY" /data/local/tmp/overlay.tar.gz
adb push "$DEVSH" /data/local/tmp/flash-rootfs.sh
adb shell chmod +x /data/local/tmp/flash-rootfs.sh
adb shell sh /data/local/tmp/flash-rootfs.sh

echo "======================================"
echo " 写入完成，重启设备 ..."
echo " 登录用户：fnos   密码：admin1234"
echo "======================================"
adb reboot || fastboot reboot || true
