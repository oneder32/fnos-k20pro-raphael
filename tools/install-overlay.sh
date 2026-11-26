#!/bin/bash
# fnOS K20 Pro (raphael / SM8150) 驱动 + 蓝牙 + 电源 overlay 安装脚本
# 在已进入 fnOS 系统的 root 终端执行：bash install-overlay.sh
set -e

[ "$(id -u)" = "0" ] || { echo "请用 root 执行（su - / sudo -i）"; exit 1; }

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
KERN="6.16.9-sm8150"

echo "[1/4] 叠加驱动 / 固件 / 用户态到根文件系统 ..."
tar -xzp -f "$PATCH_DIR/fnos-k20pro-drivers-overlay.tar.gz" -C /

echo "[2/4] 添加 bluetooth 用户组 (GID 120) ..."
getent group bluetooth >/dev/null || groupadd -g 120 bluetooth

echo "[3/4] 启用蓝牙 / WiFi / 高通 modem / 电源服务 ..."
MU=/etc/systemd/system/multi-user.target.wants
mkdir -p "$MU"
for s in qrtr-ns pd-mapper rmtfs tqftpserv k20-hardware k20-wifi bluetooth upower; do
    ln -sf "../../../usr/lib/systemd/system/$s.service" "$MU/$s.service"
done
mkdir -p /etc/systemd/system/bluetooth.target.wants
ln -sf "../../../usr/lib/systemd/system/k20-bluetooth.service" \
    /etc/systemd/system/bluetooth.target.wants/k20-bluetooth.service

echo "[4/4] 重建模块依赖索引 ..."
depmod -a "$KERN" 2>/dev/null || true
systemctl daemon-reload

echo
echo "完成。请重启设备：reboot"
echo "重启后在 root 终端验证："
echo "  hciconfig -a            # 应看到 hci0"
echo "  bluetoothctl show       # 控制器信息"
echo "  upower -i $(upower -e | grep battery)  # 电池电量/温度/充电状态"
echo "  dmesg | grep -iE 'btqca|hci|wcnss|qrtr|firmware|ath10k'"
