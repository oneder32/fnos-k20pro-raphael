#!/bin/sh
# =============================================================================
# fnOS 1.2.1011 / K20 Pro (raphael, SM8150) 直升包安装脚本
# 适用：已经在跑旧版 fnOS 的设备，在系统内直接叠加升级。
# 本脚本【不刷 boot、不格式化分区】，只把驱动/蓝牙/电源/用户增量叠加到根文件系统。
# 用法（root）：  sh install-upgrade.sh
# =============================================================================
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
HASH='$6$5db9e7dd94d6d58f$XCKCALHW2GWLbGETDi6sDJNyAm1cJO2VXR7jKxwcivk5JbnI8v75McCFUwqmJo1W63KLtlt5JKgJOvA.C/ttZ1'
KVER="6.16.9-sm8150"

echo "======================================"
echo " fnOS K20 Pro 直升升级 (系统内叠加) "
echo "======================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请用 root 执行（sudo sh install-upgrade.sh）"
    exit 1
fi

# 1) 叠加驱动 / 蓝牙 / modem / 电源 overlay -----------------------------------
if [ -f "$DIR/overlay.tar.gz" ]; then
    echo "[1/5] 叠加驱动/蓝牙/电源 overlay ..."
    tar -xzf "$DIR/overlay.tar.gz" -C /
else
    echo "[1/5] 未找到 overlay.tar.gz，跳过"
fi

# 2) 确保 fnos 用户存在 (UID/GID 1000, 附加组 Users) -------------------------
echo "[2/5] 检查/创建 fnos 用户 ..."
if ! grep -q '^fnos:' /etc/passwd; then
    echo "fnos:x:1000:1000:fnOS user:/home/fnos:/bin/bash" >> /etc/passwd
fi
if ! grep -q '^fnos:' /etc/group; then
    echo "fnos:x:1000:" >> /etc/group
fi
if ! grep -q '^Users:' /etc/group; then
    echo "Users:x:1001:" >> /etc/group
fi
# 附加进 Users 组
if ! getent group Users | grep -q fnos 2>/dev/null; then
    sed -i 's/^Users:x:1001:.*/Users:x:1001:fnos/' /etc/group 2>/dev/null || echo "Users:x:1001:fnos" >> /etc/group
fi
# shadow：密码 admin1234 (SHA512)，若条目缺失或被锁则写入
if ! grep -q '^fnos:' /etc/shadow; then
    echo "fnos:$HASH:20783:0:99999:7:::" >> /etc/shadow
else
    sed -i "s|^fnos:.*|fnos:$HASH:20783:0:99999:7:::|" /etc/shadow
fi
mkdir -p /home/fnos
chown -R 1000:1000 /home/fnos
chmod 755 /home/fnos

# 3) 模块依赖与服务 ------------------------------------------------------------
echo "[3/5] 刷新模块依赖与 systemd 单元 ..."
[ -d "/lib/modules/$KVER" ] && depmod "$KVER" 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true

# 4) 启用关键服务（蓝牙 / modem / 电源）---------------------------------------
echo "[4/5] 启用蓝牙 / modem / 电源管理服务 ..."
for svc in bluetooth qrtr-ns pd-mapper rmtfs tqftpserv upower; do
    systemctl enable "$svc" 2>/dev/null || true
done

# 5) 收尾 ---------------------------------------------------------------------
echo "[5/5] 完成。"
echo "--------------------------------------"
echo " 登录用户：fnos"
echo " 登录密码：admin1234"
echo " 建议重启设备使驱动与服务全部生效： reboot"
echo "======================================"
