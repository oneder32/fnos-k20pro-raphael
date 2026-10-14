#!/bin/bash
# fnOS K20Pro raphael fastboot刷写脚本
# 刷入userdata分区 sda31

set -e

IMG_NAME="fnos_k20pro_rootfs.img"

echo "====================================="
echo " fnOS ARM64 K20Pro 刷机脚本 "
echo " 目标分区：userdata (/dev/sda31)"
echo "====================================="

if [ ! -f "${IMG_NAME}" ];then
    echo "错误：找不到 ${IMG_NAME}，请将镜像放在脚本同目录！"
    exit 1
fi

echo "正在检查fastboot设备..."
fastboot devices
if [ $? -ne 0 ];then
    echo "未检测到fastboot设备，请确认手机进入fastboot模式"
    exit 1
fi

read -p "确认刷写userdata分区，所有数据会被清除！输入 y 继续：" ans
if [ "$ans" != "y" ];then
    echo "已取消刷机"
    exit 0
fi

echo "开始刷写 ${IMG_NAME} 到 userdata..."
fastboot flash userdata ${IMG_NAME}

echo "刷写完成，正在重启设备..."
fastboot reboot

echo "设备重启，请等待首次开机（首启时间较长，5分钟左右）"
