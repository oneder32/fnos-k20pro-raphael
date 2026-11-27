#!/bin/sh
# fnOS K20 Pro 启动 / 蓝牙 / modem 诊断收集
# 用法（root）： sh collect-boot-bt-diag.sh > /tmp/boot-bt-diag.txt 2>&1
# 然后把 /tmp/boot-bt-diag.txt 回传。
OUT=/tmp/boot-bt-diag.txt
{
echo "===== date ====="; date
echo "===== uname ====="; uname -a
echo "===== /proc/cmdline ====="; cat /proc/cmdline
echo "===== block devices ====="; lsblk -f 2>/dev/null; cat /proc/partitions 2>/dev/null
echo "===== blkid ====="; blkid 2>/dev/null

echo "===== failed systemd units ====="
systemctl --failed --no-pager 2>/dev/null

echo "===== bluetooth / modem / power services ====="
for s in bluetooth k20-hardware k20-wifi k20-bluetooth qrtr-ns pd-mapper rmtfs tqftpserv upower; do
    echo "--- $s ---"
    systemctl status "$s" --no-pager 2>/dev/null | head -15
done

echo "===== bluetooth hci nodes ====="
ls -l /sys/class/bluetooth/ 2>/dev/null
hciconfig -a 2>/dev/null || bluetoothctl list 2>/dev/null

echo "===== loaded modules (bt/wifi/modem/ufs) ====="
lsmod 2>/dev/null | grep -iE 'bt|hci|qca|ath10k|qrtr|rmtfs|pd-mapper|tqftp|ufs|scsi|sd_mod|wcn|qcom|fastrpc|wcss'

echo "===== dmesg: ufs / scsi / bluetooth / hci / qca / ath10k / qrtr / modem ====="
dmesg 2>/dev/null | grep -iE 'ufs|scsi|sd_mod|bluetooth|hci|btqca|hci_uart|qca|ath10k|wcn|qrtr|pd-mapper|rmtfs|tqftp|modem|pil|q6v5|wcss' | tail -120

echo "===== firmware present ====="
ls -l /lib/firmware/ath10k/WCN3990/ 2>/dev/null
find /lib/firmware -iname '*wcn*' -o -iname '*qca6*' -o -iname '*qca7*' 2>/dev/null

echo "===== rootfs users ====="
grep -E '^(fnos|root):' /etc/passwd
echo "===== diag end ====="
} > "$OUT" 2>&1
echo "written $OUT"
