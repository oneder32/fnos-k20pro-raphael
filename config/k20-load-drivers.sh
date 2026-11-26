#!/bin/bash
# K20Pro SM8150 高通硬件驱动兜底加载
# 高通 modem 服务（qrtr-ns / pd-mapper / rmtfs / tqftpserv）由独立 systemd 单元自启，
# 本脚本仅在模块未被 modules-load 加载时做兜底。

# 高通 QRTR / remoteproc 链路（qrtr 内核内置，此处兜底外置 remoteproc 模块）
/sbin/modprobe qcom_common 2>/dev/null || true
/sbin/modprobe qcom_q6v5 2>/dev/null || true
/sbin/modprobe qcom_wcnss_pil 2>/dev/null || true
/sbin/modprobe zram 2>/dev/null || true
exit 0
