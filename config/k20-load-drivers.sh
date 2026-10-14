#!/bin/bash
# K20Pro硬件驱动加载脚本

#启动高通QRTR服务
systemctl start qrtr-ns
systemctl start pd-mapper
systemctl start rmtfs
systemctl start tqftpserv

#加载内核模块
modprobe qrtr
modprobe qrtr-smd
modprobe remoteproc
modprobe zram

exit 0
