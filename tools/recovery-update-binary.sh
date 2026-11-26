#!/sbin/sh
# ============================================================================
# fnOS 1.2.1011 for Redmi K20 Pro (raphael / SM8150 / WCN3998)
# Recovery updater (TWRP / OrangeFox).
# 由 recovery 调用: update-binary <recovery> <outfd> <zip-path>
#
# 流程: 解包 zip -> 刷 boot 分区 -> 定位根分区(fnos 命名优先, sda35 兜底)
#       -> 格式化 ext4 -> 解压 rootfs -> 叠加驱动/蓝牙/电源 overlay
# ============================================================================

OUTFD=$2
ZIP=$3
[ -z "$OUTFD" ] && OUTFD=0

ui_print() {
    echo "ui_print $1" >> /proc/$OUTFD/fd 2>/dev/null || echo "$1"
    echo "ui_print" >> /proc/$OUTFD/fd 2>/dev/null
}

PKG=/tmp/fnos_pkg
rm -rf "$PKG"; mkdir -p "$PKG"

ui_print "=================================="
ui_print " fnOS 1.2.1011  K20 Pro (raphael)"
ui_print "=================================="

# ---- 1. Extract this zip ----
ui_print "[1/6] 解刷机包..."
if command -v unzip >/dev/null 2>&1; then
    unzip -o "$ZIP" -d "$PKG" >/dev/null 2>&1
elif command -v busybox >/dev/null 2>&1; then
    busybox unzip -o "$ZIP" -d "$PKG" >/dev/null 2>&1
else
    ui_print "错误: 缺少 unzip / busybox"
    exit 1
fi
[ -f "$PKG/rootfs.tar.gz" ] || { ui_print "错误: 包内缺少 rootfs.tar.gz"; exit 1; }
[ -f "$PKG/boot_fnos_k20pro.img" ] || { ui_print "错误: 包内缺少 boot 镜像"; exit 1; }

# ---- 2. Locate boot partition ----
ui_print "[2/6] 定位 boot 分区..."
BOOT_DEV=""
for link in \
    /dev/block/bootdevice/by-name/boot \
    /dev/block/platform/soc/1d84000.ufshc/by-name/boot; do
    [ -e "$link" ] && BOOT_DEV="$link" && break
done
if [ -z "$BOOT_DEV" ]; then
    for d in /dev/block/bootdevice/by-name /dev/block/platform/*/by-name /dev/block/*/by-name; do
        [ -L "$d/boot" ] && BOOT_DEV="$d/boot" && break
    done
fi
if [ -z "$BOOT_DEV" ]; then
    ui_print "未找到 boot by-name 分区, 当前块设备:"
    ls -l /dev/block/ 2>/dev/null
    cat /proc/partitions 2>/dev/null
    exit 1
fi
ui_print "boot 分区: $BOOT_DEV"

# ---- 3. Flash boot ----
ui_print "[3/6] 写入 boot 镜像..."
dd if="$PKG/boot_fnos_k20pro.img" of="$BOOT_DEV" bs=4096 2>/dev/null \
    || { ui_print "boot 写入失败"; exit 1; }
ui_print "boot 写入完成"

# ---- 4. Locate root partition: fnos-named first, fixed sda35 slot fallback ----
ui_print "[4/6] 定位 fnOS 根分区 (fnos 优先, 其次 sda35)..."
ROOT_DEV=""
for dev in /dev/sd* /dev/block/sd* /dev/mmcblk0p* /dev/block/mmcblk0p*; do
    [ -b "$dev" ] || continue
    blk=$(blkid "$dev" 2>/dev/null)
    case "$blk" in
        *'LABEL="fnos"'*|*'PARTLABEL="fnos"'*) ROOT_DEV="$dev"; break ;;
    esac
    sys="/sys/class/block/${dev##*/}/uevent"
    if [ -r "$sys" ] && grep -q '^PARTNAME=fnos$' "$sys" 2>/dev/null; then
        ROOT_DEV="$dev"; break
    fi
done
if [ -z "$ROOT_DEV" ]; then
    for dev in /dev/sda35 /dev/block/sda35 /dev/mmcblk0p35 /dev/block/mmcblk0p35; do
        [ -b "$dev" ] && ROOT_DEV="$dev" && break
    done
fi
if [ -z "$ROOT_DEV" ]; then
    ui_print "未找到根分区 (LABEL/PARTNAME=fnos 或 /dev/sda35)"
    cat /proc/partitions 2>/dev/null
    blkid 2>/dev/null
    exit 1
fi
ui_print "根分区: $ROOT_DEV"

# ---- 5. Format & unpack rootfs ----
ui_print "[5/6] 格式化 ext4 并解压根文件系统..."
mkfs.ext4 -F "$ROOT_DEV" 2>/dev/null \
    || mke2fs -F "$ROOT_DEV" 2>/dev/null \
    || { ui_print "根分区格式化失败"; exit 1; }

mkdir -p /mnt/fnos
mount -t ext4 "$ROOT_DEV" /mnt/fnos || { ui_print "根分区挂载失败"; exit 1; }
tar -xzf "$PKG/rootfs.tar.gz" -C /mnt/fnos || { ui_print "rootfs 解压失败"; exit 1; }

# ---- 6. Overlay: drivers / bluetooth / modem / power ----
ui_print "[6/6] 叠加驱动 / 蓝牙 / 电源补丁..."
if [ -f "$PKG/overlay.tar.gz" ]; then
    tar -xzf "$PKG/overlay.tar.gz" -C /mnt/fnos
    # bluetooth group (GID 120; 107 已被 _rpc 占用)
    grep -q '^bluetooth:' /mnt/fnos/etc/group 2>/dev/null \
        || echo 'bluetooth:x:120:' >> /mnt/fnos/etc/group
    # enable services
    MU=/mnt/fnos/etc/systemd/system/multi-user.target.wants
    mkdir -p "$MU"
    for s in qrtr-ns pd-mapper rmtfs tqftpserv k20-hardware k20-wifi bluetooth upower; do
        ln -sf "../../../usr/lib/systemd/system/$s.service" "$MU/$s.service"
    done
    mkdir -p /mnt/fnos/etc/systemd/system/bluetooth.target.wants
    ln -sf "../../../usr/lib/systemd/system/k20-bluetooth.service" \
        /mnt/fnos/etc/systemd/system/bluetooth.target.wants/k20-bluetooth.service
    ui_print "overlay 叠加完成"
else
    ui_print "未找到 overlay.tar.gz, 跳过补丁叠加"
fi

sync
umount /mnt/fnos 2>/dev/null

ui_print "=================================="
ui_print " 刷写完成! 请重启设备"
ui_print "=================================="
exit 0
