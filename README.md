# fnOS ARM for 红米 K20 Pro (raphael) — 刷机说明

## 概述

本镜像将 **fnOS（飞牛OS）ARM64** 移植到红米 K20 Pro / Mi 9T Pro（代号 raphael，骁龙855 SM8150），原生运行（非虚拟机），rootfs 刷入 **sda31（userdata）分区**。

### 引导链

```
ABL (Android Bootloader)
  → U-Boot          [boot 分区]
  → 内核 6.16.9-sm8150 + DTB  [cache 分区，Android boot 镜像]
  → fnOS rootfs (ext4)  [sda31 / userdata 分区]
  → fnOS WebUI (http://<IP>:5666)
```

### 镜像信息

| 项目 | 值 |
|------|-----|
| 文件 | `fnos_k20pro_rootfs.img` |
| 大小 | 6.0 GB（首启自动扩容至分区上限，fnOS 限制 16GiB） |
| 文件系统 | ext4（因 6.16.9-sm8150 内核无 BTRFS 支持，从官方 BTRFS 转换） |
| 架构 | aarch64 / ARM64 |
| fnOS 版本 | ophub/fnnas 社区 ARM 版（基于 Debian） |
| 主机名 | fnos-k20pro |
| 内核模块 | 6.16.9-sm8150（143 个 .ko，含高通 WiFi/BT/remoteproc/zram） |
| DTB | sm8150-xiaomi-raphael.dtb（/boot/dtbs/qcom/） |

---

## 前置条件

### 1. 解锁 Bootloader
- 小米账号绑定设备，申请解锁（小米解锁工具）
- `fastboot oem unlock`

### 2. 刷入 U-Boot（boot 分区）
从以下项目获取 U-Boot 镜像：
- https://github.com/ssbngb/linux-xiaomi-raphael-uboot
- https://github.com/GavinLiuOnline/xiaomi_raphael_uboot（分支，支持启动菜单）

```bash
fastboot flash boot u-boot.img
```

### 3. 刷入主线内核（cache 分区）
需要为 K20 Pro 编译的主线内核（6.16.9-sm8150 或兼容版本），打包为 Android boot 镜像：

```bash
fastboot flash cache xiaomi-k20pro-boot.img
```

> **注意**：内核 boot 镜像的 cmdline 必须包含 `root=/dev/sda31`（或对应 PARTUUID），且 DTB 为 sm8150-xiaomi-raphael。
> 如果你已有可用的 Kali Linux on K20 Pro  setup，其内核（cache 分区）可直接复用。

### 4. 确认分区表
进入 U-Boot 或 recovery，确认 sda31 为 userdata 分区：
```bash
sgdisk --print /dev/block/sda
```
> 128GB 机型扩展分区表后，ESP 通常为 sda32，userdata 为 sda31。不同固件可能有差异，务必确认。

---

## 刷机步骤

### 方法一：fastboot（推荐）

```bash
# 1. 进入 fastboot 模式（关机后 音量- + 电源）
# 2. 刷入 fnOS rootfs 到 userdata 分区
fastboot flash userdata fnos_k20pro_rootfs.img

# 3. 重启
fastboot reboot
```

### 方法二：TWRP / recovery

```bash
# 在 TWRP 中通过 adb sideload 或 dd 写入
adb push fnos_k20pro_rootfs.img /tmp/
adb shell dd if=/tmp/fnos_k20pro_rootfs.img of=/dev/block/sda31 bs=4M
```

---

## 首次启动

1. **自动扩容**：fnOS 首启会自动将 rootfs 扩容至分区大小（受 rootfs_limit_gib=16 限制）
2. **硬件初始化**：`k20-hardware.service` 自动加载高通驱动链：
   - QRTR 总线 → qrtr-ns/pd-mapper/rmtfs/tqftpserv
   - WiFi（ath10k_snoc，wlan0）
   - 蓝牙（hci_qca）
   - GPU/显示（msm）
   - 充电（qpnp-smb5）
3. **网络接入**：
   - K20 Pro 无有线网口，使用 WiFi（wlan0）
   - 通过串口或 U-Boot 控制台配置 WiFi：
     ```bash
     nmcli device wifi connect "你的SSID" password "你的密码"
     ```
   - 或使用 USB-OTG 网卡
4. **访问 fnOS WebUI**：
   - 浏览器访问 `http://<手机IP>:5666`
   - 默认账号密码按 fnOS 首次设置向导配置

---

## 已集成的 K20 Pro 硬件支持

| 组件 | 状态 | 说明 |
|------|------|------|
| WiFi (ath10k_snoc) | ✓ | k20-wifi.service 自动启用 wlan0 |
| 蓝牙 (hci_qca) | ✓ | k20-bluetooth.service |
| 高通服务链 | ✓ | qrtr-ns, pd-mapper, rmtfs, tqftpserv |
| GPU/显示 (msm) | ✓ | 模块加载 |
| 充电 (qpnp-smb5) | ✓ | 模块加载 |
| UFS 存储 | ✓ | 内核内置 |
| USB | ✓ | 内核内置 |
| 触摸屏 | ⚠ | 需确认驱动（主线 sm8150 支持） |
| 音频 | ⚠ | 可能需额外配置 |
| 摄像头 | ✗ | 主线支持有限 |

---

## 注意事项

1. **BTRFS 功能不可用**：fnOS 官方使用 BTRFS+zstd，因 6.16.9-sm8150 内核无 BTRFS，已转为 ext4。fnOS 的快照/压缩功能不可用。
2. **内核兼容性**：本 rootfs 包含 6.16.9-sm8150 内核模块。如果你使用其他版本内核，需替换 `/usr/lib/modules/` 下的模块。
3. **数据丢失**：刷入 userdata 分区会清除所有原有数据，请提前备份。
4. **Modem/EFS**：刷机不影响 modem 分区，但建议先备份 EFS。
5. **fnOS 更新**：fnOS 在线更新可能覆盖定制文件（k20 服务、fstab 等），更新后需检查。

---

## 参考项目

- U-Boot + 内核引导：https://github.com/ssbngb/linux-xiaomi-raphael-uboot
- U-Boot 分支（启动菜单）：https://github.com/GavinLiuOnline/xiaomi_raphael_uboot
- fnOS ARM 社区镜像：https://github.com/ophub/fnnas
- WoA 分区教程：https://github.com/woa-raphael/woa-raphael
- fnOS 官方：https://fnnas.com/download-arm
