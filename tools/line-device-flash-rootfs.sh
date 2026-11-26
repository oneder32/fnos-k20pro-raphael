#!/bin/sh
# =============================================================================
# 线刷设备端脚本（在手机 adb shell 内以 root 执行）
# 定位根分区：LABEL/PARTLABEL/PARTNAME 含 fnos 优先；否则兜底 /dev/sda35
# 格式化 ext4 -> 挂载 -> 解压 rootfs -> 叠加 overlay -> 修正 fnos home 属主
# =============================================================================
set -e

ROOTFS_TAR="/data/local/tmp/rootfs.tar.gz"
OVERLAY_TAR="/data/local/tmp/overlay.tar.gz"
MNT="/mnt/fnos"

echo "[设备端] 定位根分区 ..."
ROOTDEV=""
for d in /dev/sda* /dev/block/by-name/*; do
    [ -b "$d" ] || continue
    lbl="$(blkid -s PARTLABEL -o value "$d" 2>/dev/null)"
    lab="$(blkid -s LABEL -o value "$d" 2>/dev/null)"
    case "${lbl}${lab}" in
        *fnos*) ROOTDEV="$d"; break ;;
    esac
done
[ -z "$ROOTDEV" ] && ROOTDEV="/dev/sda35"
echo "[设备端] 根分区: $ROOTDEV"

echo "[设备端] 格式化 ext4 ..."
mkfs.ext4 -F "$ROOTDEV"

mkdir -p "$MNT"
mount "$ROOTDEV" "$MNT"

echo "[设备端] 解压 rootfs ..."
tar -xzf "$ROOTFS_TAR" -C "$MNT"

if [ -f "$OVERLAY_TAR" ]; then
    echo "[设备端] 叠加 overlay ..."
    tar -xzf "$OVERLAY_TAR" -C "$MNT"
fi

# fnos 用户家目录属主兜底 (UID/GID 1000)
chown -R 1000:1000 "$MNT/home/fnos" 2>/dev/null || true
chmod 755 "$MNT/home/fnos" 2>/dev/null || true

umount "$MNT"
echo "[设备端] 根分区写入完成。"
