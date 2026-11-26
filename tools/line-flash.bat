@echo off
REM ============================================================================
REM fnOS 1.2.1011 / K20 Pro (raphael, SM8150) 线刷脚本 (Windows)
REM 流程：fastboot 刷 boot -> 重启 -> adb root -> 推送 rootfs -> 设备端写入根分区
REM 前提：已安装 Android Platform Tools (fastboot/adb)，手机已解锁。
REM ============================================================================

setlocal
set DIR=%~dp0
set BOOT=%DIR%boot_fnos_k20pro.img
set ROOTFS=%DIR%rootfs.tar.gz
set OVERLAY=%DIR%overlay.tar.gz
set DEVSH=%DIR%device-flash-rootfs.sh

echo ======================================
echo  fnOS K20 Pro 线刷 (fastboot + adb)
echo ======================================

if not exist "%BOOT%"   (echo 错误：缺少 boot_fnos_k20pro.img & exit /b 1)
if not exist "%ROOTFS%" (echo 错误：缺少 rootfs.tar.gz & exit /b 1)
if not exist "%DEVSH%"  (echo 错误：缺少 device-flash-rootfs.sh & exit /b 1)

echo [1/4] 检查 fastboot 设备 ...
fastboot devices
if errorlevel 1 (echo 未检测到 fastboot 设备，请进入 fastboot 模式 & exit /b 1)

set /p ans=确认刷写 boot 与根分区，根分区数据将被清除！输入 y 继续：
if /i not "%ans%"=="y" (echo 已取消 & exit /b 0)

echo [2/4] fastboot 刷写 boot 分区 ...
fastboot flash boot "%BOOT%"

echo [3/4] 重启设备并等待 adb ...
fastboot reboot
timeout /t 6 /nobreak >nul
adb wait-for-device
adb root
timeout /t 3 /nobreak >nul

echo [4/4] 推送 rootfs / overlay / 设备端脚本 ...
adb push "%ROOTFS%" /data/local/tmp/rootfs.tar.gz
if exist "%OVERLAY%" adb push "%OVERLAY%" /data/local/tmp/overlay.tar.gz
adb push "%DEVSH%" /data/local/tmp/flash-rootfs.sh
adb shell chmod +x /data/local/tmp/flash-rootfs.sh
adb shell sh /data/local/tmp/flash-rootfs.sh

echo ======================================
echo  写入完成，重启设备 ...
echo  登录用户：fnos   密码：admin1234
echo ======================================
adb reboot
endlocal
