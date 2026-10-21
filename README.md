# fnOS 适配红米 K20 Pro（raphael / sm8150）

> 在红米 K20 Pro / Mi 9T Pro 上原生运行 fnOS 飞牛私有云，非虚拟机、非 chroot。
> 目标分区：**`/dev/sda35`**（rootfs），内核 6.16.9-sm8150 + raphael DTB。

[![Device](https://img.shields.io/badge/Device-Redmi%20K20%20Pro-red)](https://www.mi.com)
[![Architecture](https://img.shields.io/badge/Architecture-aarch64%20ARM64-blue)](#)
[![fnOS](https://img.shields.io/badge/fnOS-1.2.0701%20armsr-orange)](#)
[![Kernel](https://img.shields.io/badge/Kernel-6.16.9--sm8150-green)](#)
[![Status](https://img.shields.io/badge/Status-Experimental-yellow)](#)
[![License](https://img.shields.io/badge/License-MIT-lightgrey)](#)

---

## 📱 项目介绍

本仓库是 fnOS 官方 ARM 版在 **红米 K20 Pro（代号 `raphael`，骁龙 855 / SM8150）** 上的完整适配包。

- **原生运行**：sm8150 主线内核 + fnOS 用户态，跑在手机硬件上，不经过虚拟机
- **官方底包**：基于 `fnos_Mainland-PE_arm_1.2.0701_armsr_2881.iso`，Debian 12.12 用户态
- **手机驱动烘焙在内**：UFS、WiFi（ath10k/WCN3990）、蓝牙、GPU（Adreno 640）、充电、高通 modem 服务
- **根分区**：`/dev/sda35`（ext4 / f2fs 均可）

### 引导链结构

```
ABL (高通 Bootloader)
  │
  ├──→ boot 分区   → boot_fnos_k20pro.img
  │                    ├─ Linux 6.16.9-sm8150 内核
  │                    ├─ raphael DTB（内核末尾追加）
  │                    └─ initramfs（手机启用层 + 挂载脚本）
  │
  ├──→ dtbo 分区   → dtbo.img（可选，结构有效版）
  │
  └──→ sda35       → fnOS rootfs（ext4，含全套 /usr/trim/bin 服务）
                     │
                     └──→ WebUI: http://<手机IP>:5666
```

### 原理说明

1. K20 Pro 走 **bootloader → boot.img**（内核 + DTB + initramfs）启动，不能走 fnOS 原生的 UEFI/GRUB。
2. fnOS 自带的 `6.18.18.c1147-trim` 是通用 armsr 内核，没有 K20 Pro 设备树，在手机上用不了；所以**内核用 6.16.9-sm8150（boot.img 自带）**。
3. initramfs 是「手机启用层」：挂载 `/dev/sda35`（ext4 优先，f2fs 兜底），首次启动把以下内容合并进根文件系统后 `switch_root` 到 systemd：
   - `/usr/lib/modules/6.16.9-sm8150/`（内核模块）
   - `/usr/lib/firmware/`（高通 / ath10k 固件，含 WCN3990 WiFi）
   - `/usr/bin/{pd-mapper,qrtr-ns,rmtfs,tqftpserv}` + systemd 单元（高通 modem 服务）
   - `/etc/modprobe.d`、`/etc/modules-load.d` 的 raphael-wifi 配置、NetworkManager 配置
4. fnOS 在手机上是**用户态 NAS 系统**跑在 sm8150 内核之上。

---

## 📦 产物清单

| 文件 | 大小 | 说明 |
|------|------|------|
| `Redmi_K20pro_FnOS线刷包.zip` | 2.0 GB | 查看刷机步骤 |
| `Redmi_K20pro_FnOS卡刷包.zip` | 2.0 GB | 可使用第三方rec卡刷 |
| `rootfs.tar.gz` | ~1.8 GB | fnOS 根文件系统 tar 包，fstab 已改、手机驱动已烘焙在内，单包即可 |
| `boot.img` | ~14 MB | 启动镜像：6.16.9 内核 + raphael DTB + initramfs，根分区指向 `/dev/sda35` |
| `dtbo.img` | — | 由 raphael DTB 重新生成的有效 dtbo（原来那份 32MB 全零，无效） |


> 二选一：`tar.gz` 走 recovery 解压（灵活、支持 f2fs）；`.img` 走 fastboot 直刷（快、ext4）。

---

## 🚀 下载方式

> 所有刷机文件均通过 **GitHub Release** 或 **123 云盘** 分发，仓库内不存放大文件。

### 方式一：GitHub Release（推荐）

进入仓库 **Releases** 页面，下载所需文件：

🔗 **Releases 页面**：https://github.com/oneder32/fnos-k20pro/releases/latest

| 文件 | 说明 |
|------|------|
| `rootfs.tar.gz` | fnOS 根文件系统 tar 包（走 recovery 解压，约 1.8 GB） |
| `boot.img` | 启动镜像（内核 + DTB + initramfs，约 14 MB） |
| `dtbo.img` | 有效 dtbo 分区镜像（约 32 MB） |

命令行下载示例：

```bash
#Redmi_K20pro_FnOS_Line_Brush_Package.zip(线刷包)
wget https://github.com/oneder32/fnos-k20pro/releases/latest/download/Redmi_K20pro_FnOS_Line_Brush_Package.zip
gunzip Redmi_K20pro_FnOS_Line_Brush_Package.zip

# Redmi_K20pro_FnOS_Card_Brush_Package.zip(卡刷包)
wget https://github.com/oneder32/fnos-k20pro/releases/latest/download/ Redmi_K20pro_FnOS_Card_Brush_Package.zip

```

### 方式二：123 云盘（国内加速）

GitHub 下载慢或打不开时，使用 123 云盘备用链接：

🔗 **分享链接**：https://1819188641.share.123pan.cn/123pan/fhQ9jv-NhGWv?pwd=fnos

🔑 **提取密码**：`fnos`

云盘内文件与 GitHub Release 完全一致，按需下载即可。手机浏览器也可直接打开。

---

## 📋 前置条件

- ✅ 红米 K20 Pro（raphael）已 **解锁 Bootloader**
- ✅ 电脑已安装 `adb` + `fastboot`
- ✅ 电量 > 50%，数据线稳定
- ✅（可选）TWRP / OrangeFox recovery（用于 tar.gz 解压方式）

> ⚠️ **本操作会覆盖 `/dev/sda35` 现有内容**（你原来的 Ubuntu/Kali 根分区）。动手前务必备份数据。刷机有风险，变砖/数据丢失自行承担。

---

## 🔧 刷机步骤

### 第 0 步：备份（强烈建议）

```bash
adb reboot bootloader
fastboot getvar current-slot   # 记下当前槽位 a/b
# 若有 TWRP/OrangeFox，先进 recovery 备份整个 /dev/sda35
```

### 第 1 步：写入根文件系统到 /dev/sda35

**解压方式：tar.gz + Recovery（推荐，灵活）**

进入 TWRP / OrangeFox（需支持 adb shell）：

```bash
# 推送 tar 包到手机存储
adb push rootfs.tar.gz /sdcard/

# 进 recovery 的 adb shell
adb shell

# 先确认 sda35 节点存在
ls /dev/block/ | grep sda3

# 格式化 sda35（⚠️ 会清空数据）
mkfs.ext4 /dev/block/sda35
mkdir -p /mnt/root
mount /dev/block/sda35 /mnt/root

# 解压根文件系统（必须在手机上用 tar 解压，Windows 解压会丢符号链接）
tar -xzf /sdcard/rootfs.tar.gz -C /mnt/root
sync
umount /mnt/root
exit
```

> 若想保留 f2fs：把 `mkfs.ext4` 换成 `mkfs.f2fs`；init 脚本会先试 ext4 再试 f2fs。


### 第 2 步：刷入 boot 与 dtbo

```bash
adb reboot bootloader

fastboot flash boot boot_fnos_k20pro.img
fastboot flash dtbo dtbo.img        # 可选；主线启动实际用内核末尾追加的 DTB

fastboot reboot
```

---

## 🖥️ 首次启动

1. **首次启动较慢**：initramfs 会把「手机启用层」（模块/固件/高通服务）合并进根分区，第二次起会正常速度。
2. **自动扩容**：首启自动 `resize2fs` 扩展到分区全部空间。
3. **配网**：K20 Pro 无原生网口，用 WiFi（wlan0）或 USB 网卡：
   ```bash
   nmcli device wifi connect "你的WiFi名" password "WiFi密码"
   ```
4. **访问 WebUI**：
   ```
   http://<手机IP>:5666
   ```
   按引导设置管理员账号、存储池。

---

## ✅ 启动自检

```bash
uname -r              # 应显示 6.16.9-sm8150（不是 6.18.18）
hostname              # trim 或 fnos-k20pro
mount | grep ' / '    # 根应是 /dev/sda35
ls /lib/modules/       # 应看到 6.16.9-sm8150
ls /lib/firmware/qcom  # 应看到 sm8150/raphael 的 modem/adsp 固件
```

---

## 🔄 回滚

```bash
# 恢复原 boot / dtbo
fastboot flash boot 原boot.img
fastboot flash dtbo 原dtbo.img   # 没有就跳过

# 恢复 /dev/sda35 里的旧根文件系统（用你之前的备份方式）
```

---

## 🛠️ 已知问题与说明

| 项目 | 状态 | 备注 |
|------|------|------|
| UFS 存储 | ✅ | /dev/sda35 |
| WiFi (ath10k/WCN3990) | ✅ | wlan0 |
| 蓝牙 (hci_qca) | ✅ | — |
| GPU (Adreno 640) | ✅ 驱动加载 | 3D 加速需 Mesa 配置 |
| 充电管理 | ✅ | qpnp-smb5 |
| 触摸屏 | ⚠️ 需确认 | 主线内核支持情况 |
| 音频 | ⚠️ 需配置 | snd-soc-sm8150 |
| 摄像头 | ❌ 不支持 | 主线支持有限 |
| 显示 | ⚠️ 可能黑屏/花屏 | 黑屏时 cmdline 加 `video=DSI-1:1080x2340@60 fbcon=nodefer` |

其他注意事项：

1. **不要升级内核**：手机跑的是 6.16.9-sm8150；fnOS 自带的 6.18.18 内核/模块在手机上无效。`apt upgrade` 升级 Debian 包不影响 sm8150 内核，但不要尝试替换 `/usr/lib/modules/6.16.9-sm8150`。
2. **网络**：fnOS 是 NAS，首选有线；手机没有原生以太网，用 WiFi 或 USB 网卡/RNDIS。`trim_nic_name_consistency.service` 可能重命名网卡，网络起不来先查它。
3. **存储服务**：`trim_diskpowerd` / `trim_raid_check` 面向 SATA/SAS，在手机 UFS 上行为可能与真机 NAS 不同，属预期。
4. **modem 服务**：pd-mapper/qrtr-ns/rmtfs/tqftpserv 是高通 modem 用的，不用可 `systemctl disable`。
5. **dtbo 可选**：主线启动实际用 boot.img 内核末尾追加的 DTB，不读 dtbo；本包的 dtbo.img 是结构有效版，刷不刷都行。

---

## 🩹 故障排查（掉进 busybox 时）

boot.img 的 init 脚本带诊断输出。若停在 busybox，屏幕会打印三种报错之一：

### 1. `ROOT DEVICE NOT FOUND`
没找到 `/dev/sda35`。脚本会列出 `/proc/partitions`，据此确认：
- 你的根分区到底是不是 sda35
- UFS 是否被识别（`/dev/sda*` 是否存在）

### 2. `MOUNT FAILED`
找到设备但挂载失败（ext4/f2fs 都不行）。通常是：
- 分区没格式化
- 根文件系统还没解压进去
脚本会打印 `blkid` 和 `dmesg` 尾部。

### 3. `NO INIT FOUND IN ROOTFS`
根分区挂上了但找不到 init。**多半是解压时符号链接丢了**——
⚠️ 不能用 Windows 资源管理器 / 7-Zip 在 Windows 里解压 tar.gz，必须在手机 recovery 里 `tar -xzf` 解压才能保留符号链接。

> 本包已修复一个已知问题：fnOS 的 `/usr/sbin/init` 是指向 `/lib/systemd/systemd` 的符号链接，旧 init 脚本 `-e /mnt/sbin/init` 会误判「无 init」。现在直接检查 `/mnt/usr/lib/systemd/systemd` 真实二进制，并对 switch_root 加了兜底路径。

---

## 🔍 校验文件完整性

```bash
sha256sum boot_fnos_k20pro.imgRedmi_K20pro_FnOS_Line_Brush_Package.zip
sha256sum Redmi_K20pro_FnOS_Card_Brush_Package.zip
# 按 Release 页面公布的 SHA256 核对
```

---

## 📚 参考资料

- [fnOS 官方网站](https://fnnas.com/)
- [fnOS ARM ISO 下载](https://iso.liveupdate.fnnas.com/arm/iso/armsr/)
- [Xiaomi_Kernel_OpenSource (MI 开源内核)](https://github.com/MiCode/Xiaomi_Kernel_OpenSource)

---

## 📄 License

MIT License — 仅供学习研究使用，刷机有风险，操作前务必备份数据。

## 🙏 致谢

- fnnas.com 提供官方 ARM 版系统
- Kali on K20 Pro 社区提供 SM8150 主线内核与硬件适配