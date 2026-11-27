#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin

# ---- 基础文件系统 ----
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
if ! mount -t devtmpfs dev /dev 2>/dev/null; then
    mount -t tmpfs dev /dev
    [ -e /dev/null ]    || mknod -m 666 /dev/null c 1 3
    [ -e /dev/console ] || mknod -m 620 /dev/console c 5 1
    [ -e /dev/tty ]     || mknod -m 666 /dev/tty c 5 0
fi
mount -t tmpfs run /run 2>/dev/null
mount -t tmpfs tmp /tmp 2>/dev/null

# 禁止 panic 自动重启，便于进入 shell 排查
echo 0 > /proc/sys/kernel/panic 2>/dev/null
echo 0 > /proc/sys/kernel/panic_on_oops 2>/dev/null

# ---- 存储 / 文件系统模块 ----
KERNEL_VER=$(ls /usr/lib/modules/ 2>/dev/null | head -1)
MODDIR="/usr/lib/modules/${KERNEL_VER}"
for m in scsi_mod sd_mod ufs-qcom ext4 f2fs; do
    ko=$(find "$MODDIR" -name "${m}.ko*" 2>/dev/null | head -1)
    [ -n "$ko" ] && insmod "$ko" 2>/dev/null
done
sleep 1

# ============================================================================
# 根分区探测
#   候选 A(优先): 文件系统 LABEL / GPT PARTLABEL / PARTNAME = "fnos"
#   候选 B(兜底): 固定槽位 /dev/sda35
#   两者并存时 fnos 命名分区优先。
# ============================================================================
is_fnos_dev() {
    dev="$1"
    blk=$(blkid "$dev" 2>/dev/null)
    case "$blk" in
        *'LABEL="fnos"'*|*'PARTLABEL="fnos"'*) return 0 ;;
    esac
    uevent="/sys/class/block/${dev##*/}/uevent"
    if [ -r "$uevent" ] && grep -q '^PARTNAME=fnos$' "$uevent" 2>/dev/null; then
        return 0
    fi
    return 1
}

FNOS_DEV=""
SLOT_DEV=""
for dev in /dev/sd* /dev/block/sd* /dev/mmcblk0p* /dev/block/mmcblk0p*; do
    [ -b "$dev" ] || continue
    if is_fnos_dev "$dev"; then FNOS_DEV="$dev"; break; fi
done
for dev in /dev/sda35 /dev/block/sda35 /dev/mmcblk0p35 /dev/block/mmcblk0p35; do
    [ -b "$dev" ] && SLOT_DEV="$dev" && break
done

ROOT_DEV=""
ROOT_SRC=""
if [ -n "$FNOS_DEV" ]; then
    ROOT_DEV="$FNOS_DEV"; ROOT_SRC="fnos-named"
elif [ -n "$SLOT_DEV" ]; then
    ROOT_DEV="$SLOT_DEV"; ROOT_SRC="sda35-slot"
fi

if [ -z "$ROOT_DEV" ]; then
    echo "========== ROOT DEVICE NOT FOUND =========="
    echo "tried: LABEL/PARTLABEL/PARTNAME=fnos, then /dev/sda35"
    ls -l /dev/sd* /dev/block/ /dev/mmcblk0p* 2>/dev/null
    cat /proc/partitions 2>/dev/null
    blkid 2>/dev/null
    echo "Dropping to shell."
    exec /bin/sh
fi

echo "root device: $ROOT_DEV (source: $ROOT_SRC)"
mkdir -p /mnt

if ! mount -t ext4 "$ROOT_DEV" /mnt 2>/dev/null; then
    if ! mount -t f2fs "$ROOT_DEV" /mnt 2>/dev/null; then
        echo "========== MOUNT FAILED: $ROOT_DEV =========="
        blkid "$ROOT_DEV" 2>/dev/null
        echo "Dropping to shell."
        exec /bin/sh
    fi
fi
echo "root mounted at /mnt"

# ---- 首启合并手机适配层（etc/usr）----
MERGE_MARKER="/mnt/.initramfs_merged"
if [ ! -f "$MERGE_MARKER" ]; then
    echo "first boot: merging /etc and /usr into rootfs"
    for dir in etc usr; do
        if [ -d "/$dir" ]; then
            mkdir -p "/mnt/$dir"
            cp -af "/$dir/." "/mnt/$dir/" 2>/dev/null
        fi
    done
    echo "merged" > "$MERGE_MARKER" 2>/dev/null
    chmod 644 "$MERGE_MARKER" 2>/dev/null
fi

# ---- 定位真实 init ----
INIT=""
for c in /mnt/usr/lib/systemd/systemd /mnt/sbin/init /mnt/init; do
    [ -e "$c" ] && INIT="$c" && break
done
if [ -z "$INIT" ]; then
    echo "========== NO INIT IN ROOTFS =========="
    ls -la /mnt/ 2>/dev/null
    exec /bin/sh
fi
echo "init found: $INIT"

mount --move /dev /mnt/dev 2>/dev/null
mount --move /run /mnt/run 2>/dev/null
mount --move /tmp /mnt/tmp 2>/dev/null

exec switch_root /mnt /sbin/init 2>/dev/null \
  || exec switch_root /mnt /usr/lib/systemd/systemd 2>/dev/null \
  || exec switch_root /mnt /init 2>/dev/null \
  || exec /bin/sh
