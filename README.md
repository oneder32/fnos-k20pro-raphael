# fnOS 适配红米 K20 Pro（raphael / sm8150）刷机说明

本目录是「完整适配包」。目标：让飞牛私有云（fnOS）跑在红米 K20 Pro 上，
分区用 **`/dev/sda35`**，安装方式沿用你现有的「把根文件系统 tarball 复制进分区」的套路。

## 一、产物清单（`dist/` 目录）

| 文件 | 说明 |
|---|---|
| `fnos_k20pro_rootfs.tar.gz` | fnOS 根文件系统（Debian 12.12），fstab 已改、**手机驱动已烘焙在内**，单包即可 |
| `boot_fnos_k20pro.img` | 改造后的启动镜像：sm8150 内核 + raphael DTB + initramfs，根分区指向 `/dev/sda35` |
| `dtbo.img` | 由 raphael DTB 重新生成的有效 dtbo（你原来的那份是 32MB 全零，无效） |

## 二、原理

1. K20 Pro 只能走 **fastboot → boot.img**（内核 + DTB + initramfs）启动，不能走 fnOS 原生的 UEFI/GRUB。
2. 手机硬件必须用 **sm8150 主线内核 + DTB**；fnOS 自带的 `6.18.18.c1147-trim` 是通用 armsr 内核，
   没有 K20 Pro 的设备树，在手机上用不了。所以**内核用 boot.img 里那套 6.16.9-sm8150**。
3. `boot.img` 的 initramfs 是「手机启用层」：它挂载 `/dev/sda35`（ext4 优先，f2fs 兜底），
   并在**首次启动时**把下面这些东西合并进根文件系统：
   - `/usr/lib/modules/6.16.9-sm8150/`（内核模块）
   - `/usr/lib/firmware/`（高通/ath10k 固件，含 wifi WCN3990）
   - `/usr/bin/{pd-mapper,qrtr-ns,rmtfs,tqftpserv}` + systemd 单元（高通 modem 服务）
   - `/etc/modprobe.d`、`/etc/modules-load.d` 的 raphael-wifi 配置、NetworkManager 配置
   然后 `switch_root` 到 fnOS 的 systemd。
4. fnOS 在手机上只是**用户态 NAS 系统**跑在 sm8150 内核之上。

## 三、前置条件 / 风险

- **已解锁 Bootloader** 的 K20 Pro。
- 电脑有 `adb` + `fastboot`。
- ⚠️ **本操作会覆盖 `/dev/sda35` 现有内容**（你现在的 Ubuntu/Kali）。动手前先备份。
- ⚠️ 刷机有风险，变砖/数据丢失自行承担；建议全程保持电量充足。

## 四、步骤

### 0. 备份（强烈建议）

```bash
# 备份原 boot / dtbo 分区（便于回滚）
adb reboot bootloader
fastboot getvar current-slot   # 记下当前槽位 a/b
# 若有 TWRP/OrangeFox，先进 recovery 备份整个 /dev/sda35 或把里面的数据拷出来
```

### 1. 写入根文件系统到 /dev/sda35

进入 recovery（TWRP / OrangeFox，需支持 adb shell），把 tarball 推到手机：

```bash
adb push dist/fnos_k20pro_rootfs.tar.gz /sdcard/
```

在 recovery 的 adb shell 里（设备节点名以你实际为准，先 `ls /dev/block/` 确认）：

```bash
# 找到 sda35 对应的设备节点，通常是 /dev/block/sda35
ls /dev/block/ | grep sda3

mkfs.ext4 /dev/block/sda35            # 格式化（⚠️ 会清空）
mkdir -p /mnt/root
mount /dev/block/sda35 /mnt/root
tar -xzf /sdcard/fnos_k20pro_rootfs.tar.gz -C /mnt/root   # 单包，已含手机驱动
sync
umount /mnt/root
```

> 若分区当前是 f2fs 且想保留 f2fs，可把 `mkfs.ext4` 换成 `mkfs.f2fs`；
> boot.img 的 init 脚本会先试 ext4、再试 f2fs，两者都能启动。

### 2. 刷入 boot 与 dtbo

```bash
adb reboot bootloader
fastboot flash boot dist/boot_fnos_k20pro.img
fastboot flash dtbo dist/dtbo.img      # 可选；主线启动实际用内核自带 DTB
fastboot reboot
```

### 3. 首次启动

- 首次启动 initramfs 会把手机启用层合并进根分区，**会比后续启动略慢**；
- 合并完成后正常进入 fnOS（systemd + `trim_*` 服务）。

## 五、自检

```bash
uname -r          # 应显示 6.16.9-sm8150（而不是 6.18.18）
hostname          # trim
mount | grep ' / '       # 根应是 /dev/sda35
ls /lib/modules/          # 应看到 6.16.9-sm8150（6.18.18 目录可忽略/删除）
ls /lib/firmware/qcom     # 应能看到 sm8150/raphael 的 modem/adsp 等固件
```

## 六、回滚

```bash
# 恢复你备份的 boot / dtbo
fastboot flash boot 原boot.img
fastboot flash dtbo 原dtbo.img   # 或跳过，dtbo 本来就无效
# 恢复 /dev/sda35 里的旧根文件系统（用你之前的备份方式）
```

## 七、注意事项 / 已知限制

1. **内核**：手机用的是 6.16.9-sm8150（boot.img 自带），fnOS 自带的 6.18.18 内核/模块在手机上无效，
   建议不要 `apt upgrade` 到覆盖 `6.16.9-sm8150` 模块（升级 Debian 内核不影响 sm8150 内核本身）。
2. **网络**：手机网卡是 wlan0（ath10k_snoc/WCN3990）+ USB。fnOS 是 NAS，首选有线网卡；
   手机没有原生以太网，需要 wifi 或 USB 网卡/RNDIS。首次启动后按需用 `nmcli`/`nmtui` 配网。
   fnOS 的 `trim_nic_name_consistency.service` 可能会重命名网卡，若网络起不来先查这个服务。
3. **存储**：fnOS 的 `trim_diskpowerd` / `trim_raid_check` 等面向 SATA/SAS 磁盘的服务，
   在手机上看到的是 UFS（`/dev/sda`）+ 可能的 USB 盘，行为可能与真机 NAS 不同，属于预期现象。
4. **modem/wifi**：首次启动合并的 pd-mapper/qrtr-ns/rmtfs/tqftpserv 服务是给高通 modem 用的，
   若用不到可以 `systemctl disable`。
5. **dtbo.img 是可选项**：主线内核启动时用的是 boot.img 内核末尾追加的 DTB，
   并不读取 dtbo；这里只是把原来那份全零的 dtbo 换成一个结构有效、内容正确的版本。

## 八、故障排查（掉进 busybox 时）

`boot_fnos_k20pro.img` 的 init 脚本已经带了清晰的诊断输出。若启动后停在 busybox，
屏幕上会打印三种明确的报错之一

1. **`ROOT DEVICE NOT FOUND`** —— 没找到 `/dev/sda35`。
   脚本会列出 `/proc/partitions`，据此确认你的根分区到底是不是 `sda35`，
   以及 UFS 是否被正确识别（`/dev/sda*` 是否存在）。

2. **`MOUNT FAILED`** —— 找到了设备但挂载失败（ext4/f2fs 都不行）。
   通常是分区没格式化、或根文件系统还没解压进去。脚本会打印 `blkid` 和 `dmesg` 尾部。

3. **`NO INIT FOUND IN ROOTFS`** —— 根分区挂上了但找不到 init。
   多半是解压时符号链接丢了（**不能用 Windows 资源管理器/7-Zip 在 Windows 里解压**，
   必须在手机的 recovery 里用 `tar -xzf` 解压，才能保留符号链接）。

> 注：本包已修复一个已知问题——fnOS 的 `/usr/sbin/init` 是指向绝对路径
> `/lib/systemd/systemd` 的符号链接，旧 init 脚本用 `-e /mnt/sbin/init` 判断时
> 会把它解析到 initramfs 自身而误判「无 init」。现在直接检查
> `/mnt/usr/lib/systemd/systemd` 这个真实二进制，并对 `switch_root` 增加了兜底路径。
