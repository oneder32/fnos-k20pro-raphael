# 故障排查 fnOS K20Pro

## 1. 开机黑屏无法进入系统
1. 检查U-Boot是否正确刷入boot分区
2. cache分区内核镜像是否刷写成功，确认cmdline `root=/dev/sda31`
3. sgdisk确认userdata分区编号确实是`sda31`
4. 镜像是否完整，校验SHA256

## 2. 系统启动成功，无WiFi
1. 查看服务状态：`systemctl status k20-wifi`
2. 手动加载驱动：`modprobe ath10k_snoc`
3. 检查高通qrtr/rmtfs服务是否正常运行
4. 查看内核日志：`dmesg | grep ath10k`

## 3. fnOS网页打不开
1. 确认手机WiFi联网成功：`ping 8.8.8.8`
2. 检查5666端口监听：`ss -tulnp | grep 5666`
3. 防火墙放行5666端口

## 4. fnOS升级后硬件失效
fnOS系统更新会覆盖定制文件，解决办法：
1. 重新拷贝config下所有systemd服务、udev规则、modules-load配置
2. 重新启用：
```bash
systemctl daemon-reload
systemctl enable --now k20-hardware k20-wifi k20-bluetooth
