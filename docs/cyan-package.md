# fnOS 1.2.1011 · 红米 K20 Pro（raphael / SM8150）卡刷包

## 分区引导优先级

boot 内核的 initramfs 在寻找根分区时按以下顺序：

1. **fnos 命名分区（优先）**：文件系统 `LABEL="fnos"`、GPT `PARTLABEL="fnos"` 或分区名 `PARTNAME=fnos`
2. **固定槽位兜底**：`/dev/sda35`（含 `/dev/block/sda35`、`mmcblk0p35`）

两者同时存在时，**优先启动 fnos 命名分区**；找不到 fnos 命名分区才回退 sda35。

> 刷入后若你把 fnOS 根分区的卷标/GPT 分区名设为 `fnos`，无论它落在哪个槽位，boot 都会优先引导它；sda35 仅作为默认兜底槽。

## 包内文件

| 路径 | 说明 |
|------|------|
| `META-INF/com/google/android/update-binary` | recovery 安装脚本（sh）：刷 boot、定位根分区、格式化、解压 rootfs、叠加 overlay |
| `META-INF/com/google/android/updater-script` | edify 兼容占位 |
| `boot_fnos_k20pro.img` | 6.16.9-sm8150 内核 + raphael DTB + initramfs |
| `rootfs.tar.gz` | 1.2.1011 完整根文件系统（驱动/蓝牙/modem/电源已烘焙） |
| `overlay.tar.gz` | 独立驱动/蓝牙/电源补丁包（已随 rootfs 一并叠加） |
| `install-overlay.sh` | overlay 设备端安装脚本（包内已自动执行，留作手动重修） |
| `patch/init_script.sh` | 当前 boot initramfs 使用的 init 脚本源码（双分区探测，fnos 优先） |

## 刷入步骤（TWRP / OrangeFox）

1. 备份原有 boot 与 sda35 数据。
2. 将本 zip 推到手机存储：`adb push fnos-k20pro-cyan-1.2.1011.zip /sdcard/`
3. 进 recovery → **Install / 安装** → 选择本 zip → 确认刷入。
4. 脚本会自动：刷写 boot 分区 → 定位根分区 → 格式化为 ext4 → 解压 rootfs → 叠加驱动/蓝牙/电源补丁。
5. 完成后重启。

## 首次启动自检（root 终端）

```bash
uname -r                                   # 6.16.9-sm8150
mount | grep ' / '                          # 根为所选根分区
hciconfig -a                               # hci0
ip link show wlan0
upower -i $(upower -e | grep -i battery)   # 电量/温度/充电状态
systemctl status bluetooth k20-hardware upower qrtr-ns pd-mapper rmtfs tqftpserv
```

## 注意

- 刷入会**格式化根分区**（fnos 命名分区或 sda35），动手前务必备份。
- 若 recovery 找不到 boot 的 by-name 分区，脚本会列出 `/dev/block` 与 `/proc/partitions` 后中止，不会误刷。
- 内核保持 `6.16.9-sm8150`；不要用 fnOS 自带的 6.18.18 内核/模块替换。
