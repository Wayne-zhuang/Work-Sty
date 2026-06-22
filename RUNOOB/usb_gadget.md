
[[Linux 子系统汇总]]

在 Linux 里，USB gadget 指的是：**Linux 设备作为 USB 从设备/外设端，被电脑或其他 host 识别**。

比如手机插到电脑上，电脑是 USB Host，手机就是 USB Device/Gadget。

---

**USB Host 和 USB Gadget 区别**

`USB Host： 主机端，负责枚举设备、供电、发起传输 例子：PC、车机、开发板 USB host 口 
USB Gadget： 设备端，被 host 枚举 例子：手机、U 盘、USB 网卡、USB 摄像头、ADB 设备 USB OTG / DRD： 同一个 USB 控制器既能做 host，也能做 device 通过 ID pin、Type-C role、软件配置切换角色`

手机接电脑时：

`PC: USB Host 手机: USB Gadget`

手机接 U 盘时：

`手机: USB Host U 盘: USB Device`

---

**USB Gadget 子系统作用**

USB gadget 子系统让 Linux 设备模拟成各种 USB 设备。

可以模拟：

`U 盘 串口 网卡 ADB MTP/PTP MIDI 音频设备 摄像头 HID 键盘/鼠标 调试口 复合设备`

复合设备的意思是：一个 USB 设备同时有多个功能。  
比如 Android 手机插电脑后可能同时暴露：

`ADB + MTP + RNDIS`

或者：

`ADB + ACM 串口`

---

**USB Gadget 架构**

可以这样理解：

USB Device Controller 硬件 
	↓ 
UDC driver 
	↓
USB gadget core 
	↓ 
gadget function driver 
	↓
configfs / legacy gadget 
	↓ 
用户空间配置`

核心对象：

UDC：USB Device Controller，设备端 USB 控制器 
gadget core：USB gadget 框架 
function：具体 USB 功能，比如 adb、mtp、rndis、mass_storage、hid 
configuration：USB 配置，一个配置里可以包含多个 function 
composite gadget：复合设备框架`

典型路径：

`/sys/class/udc/`

如果这个目录下有控制器，说明当前内核有 USB device controller。

---

**ConfigFS Gadget**

现代 Linux 推荐通过 configfs 创建 gadget。  
挂载点通常是：

`/sys/kernel/config/usb_gadget/`

典型创建流程：

`mount -t configfs none /sys/kernel/config 

```
cd /sys/kernel/config/usb_gadget 
mkdir g1 
cd g1 
echo 0x18d1 > idVendor echo 0x4ee7 > idProduct 
mkdir strings/0x409 
echo "1234567890" > strings/0x409/serialnumber 
echo "Android" > strings/0x409/manufacturer 
echo "Android Device" > strings/0x409/product 
mkdir configs/c.1 
mkdir configs/c.1/strings/0x409 
echo "adb" > configs/c.1/strings/0x409/configuration

```
创建 function 后链接到 config：

`mkdir functions/ffs.adb 
`ln -s functions/ffs.adb configs/c.1/`

最后绑定 UDC：

`echo <udc_name> > UDC`

取消绑定：

`echo "" > UDC`

---

**Android 上的 Gadget**

Android 手机的 USB gadget 很重要。  
常见功能：

  `adb 
```
mtp 
ptp 
rndis 
midi 
accessory 
audio_source 
mass_storage 
diag / modem / rmnet 等厂商功能`
```

Android 上 USB 模式切换通常由 framework/property/init 脚本控制。

常见属性：

	`getprop sys.usb.config 
```
	getprop sys.usb.state 
	getprop persist.sys.usb.config
```
`

例如：

`sys.usb.config=mtp,adb 
`sys.usb.state=mtp,adb`

常见 configfs 路径：

`/sys/kernel/config/usb_gadget/g1/`

Android init 脚本里经常有：

`on property:sys.usb.config=mtp,
`adb write /config/usb_gadget/g1/UDC "..."`

有些平台把 /config 挂到：

`/sys/kernel/config`

所以也可能看到：

`/config/usb_gadget/g1/`

---

**常见 Gadget Function 和应用**

**1. ADB**

用途：

`Android 调试 adb shell adb push/pull logcat fastboot 之外的在线调试`

功能名常见：

`ffs.adb`

ADB 通常基于 FunctionFS：

`functionfs`

路径可能是：

`/dev/usb-ffs/adb/`

adbd 会打开 FunctionFS endpoint，gadget 才能完整工作。

---

**2. MTP / PTP**

用途：

`手机文件传输 相册导入 媒体文件管理`

区别：

`MTP：Media Transfer Protocol，文件/媒体传输 
`PTP：Picture Transfer Protocol，偏相机照片导入`

Android 插电脑选择“文件传输”一般就是 MTP。

---

**3. RNDIS / ECM / NCM**

这些是 USB 网络功能。

`RNDIS：微软生态常见，Windows 兼容好 
`ECM：标准 USB Ethernet Control Model，Linux/macOS 常见 
`NCM：更高效的 USB 网络模型`

应用：

`USB tethering 设备通过 USB 共享网络 开发板通过 USB 网卡和 PC 通信`

Linux 侧会出现网卡：

`ifconfig usb0 ip addr show usb0`

---

**4. Mass Storage**

让设备模拟 U 盘。

应用：

`开发板把某个镜像文件暴露给 PC 老式手机 USB 存储模式 工厂烧录/维护`

configfs function 常见：

`mass_storage.0`

backing file 示例：

`echo /path/disk.img > functions/mass_storage.0/lun.0/file`

注意：

`同一个块设备不能同时被 Linux 本机挂载读写，又暴露给 PC 写。 否则文件系统容易损坏。`

---

**5. ACM 串口**

模拟 USB CDC ACM 串口。

应用：

`调试串口 AT 命令通道 嵌入式设备控制台 MCU/开发板虚拟串口`

PC 上通常看到：

`Windows: COMx 
`Linux: /dev/ttyACM0`

Gadget function：

`acm.GS0`

---

**6. HID**

模拟键盘、鼠标、游戏手柄等 HID 设备。

应用：

`USB 键盘 USB 鼠标 自动化测试 安全钥匙类设备 自定义 HID 控制器`

配置时需要 report descriptor。  
PC 上不需要额外驱动，HID 是标准 USB class。

---

**7. UVC**

模拟 USB 摄像头。

应用：

`把嵌入式设备作为 USB 摄像头 手机/开发板视频流输出到 PC 工业相机 采集卡类设备`

Linux gadget function：

`uvc`

UVC 比较复杂，需要配置 streaming、format、frame、用户空间喂视频数据。

---

**8. UAC 音频**

USB Audio Class。

应用：

`USB 麦克风 USB 声卡 音频采集/播放设备`

常见：

`uac1 uac2`

---

**9. MIDI**

USB MIDI 设备。

应用：

`乐器 音频控制器 Android MIDI 模式`

---

**10. Accessory / AOAv2**

Android Open Accessory。

用途：

`Android 设备和外设通信 车机、配件、外部控制设备`

Android 里可能有：

`accessory audio_source`

---

**11. 厂商调试功能**

手机平台常见厂商功能：

`diag serial rmnet qdss dpl modem nmea ccid`

用途：

`基带诊断 抓 modem log 工厂测试 运营商认证 射频测试 工程调试`

这些通常和 Qualcomm/MTK/vendor 驱动相关。

---

**USB Gadget 枚举流程**

从 host 角度看，大致是：

`插入 USB 
	↓ 
`Host 检测连接 
	↓ 
`Reset bus 
	↓ 
`读取 device descriptor 
	↓ 
`读取 configuration descriptor 
	↓ 
`选择 configuration 
	↓ 
`加载对应 class driver
	↓ 
`开始数据传输`

从 gadget 角度看：

`配置 descriptors / functions 
	↓ 
`绑定 UDC
	↓ 
`UDC 拉起连接 
	↓
`Host 发起枚举
	↓ 
`gadget 响应 descriptor 请求 
	↓ 
`function endpoints 启用 
	↓ 
`开始传输`

---

**Descriptor 是什么**

USB 设备通过 descriptor 告诉 host 自己是什么。

常见 descriptor：

`Device Descriptor： 
`idVendor 
`idProduct 
`bcdUSB 
`manufacturer 
`product 
`serialnumber 

`Configuration Descriptor： 一个设备有哪些配置 

`Interface Descriptor： 每个功能接口，比如 MTP、ADB、RNDIS 

`Endpoint Descriptor： 每个接口有哪些 endpoint，方向、类型、包大小`

`Endpoint 类型：

`Control 控制传输，endpoint 0 
`Bulk 大量数据，比如 ADB、MTP、U 盘 
`Interrupt 小数据低延迟，比如 HID 
`Isochronous 实时流，比如音频、视频`

---

**UDC 是什么**

UDC 是 USB Device Controller。  
它是 SoC 里的 USB 设备端控制器驱动。

查看 UDC：

`ls /sys/class/udc/`

常见名字可能类似：

`11201000.usb 
`musb-hdrc.0.auto 
`ci_hdrc.0 
`dwc3.0.auto`

绑定 gadget：

`echo 11201000.usb > /sys/kernel/config/usb_gadget/g1/UDC`

如果 /sys/class/udc/ 为空，说明：

`UDC 驱动没起来 
`USB 当前不是 device role 
`Type-C/OTG role 没切到 peripheral 
`设备树没启用 USB device controller 
`内核没打开 gadget/UDC 配置`

---

**USB Role / Type-C 关系**

现代设备经常是 Type-C DRD：

`host role device role dual role`

相关路径可能有：

`/sys/class/usb_role/`

查看：

`cat /sys/class/usb_role/*/role`

切换：

`echo device > /sys/class/usb_role/.../role 
`echo host > /sys/class/usb_role/.../role`

Type-C 还涉及：

`CC 检测 
`PD 协议 
`extcon 
`role `switch 
`charger detection`

手机插 PC 后，要先切到 peripheral/device role，gadget 才能枚举。

---

**内核配置**

常见配置项：

`CONFIG_USB_GADGET 
`CONFIG_USB_CONFIGFS 
`CONFIG_USB_CONFIGFS_F_FS 
`CONFIG_USB_CONFIGFS_MASS_STORAGE 
`CONFIG_USB_CONFIGFS_RNDIS 
`CONFIG_USB_CONFIGFS_ACM 
`CONFIG_USB_CONFIGFS_HID 
`CONFIG_USB_CONFIGFS_UVC 
`CONFIG_USB_DWC3 
`CONFIG_USB_DWC3_GADGET 
`CONFIG_USB_LIBCOMPOSITE`

Android 常见：

`CONFIG_USB_CONFIGFS_F_FS 
`CONFIG_FUNCTIONFS 
`CONFIG_USB_F_FS`

---

**调试命令**

设备端查看：

`ls /sys/class/udc/ 
`ls /sys/kernel/config/usb_gadget/ 
`find /sys/kernel/config/usb_gadget/g1 -maxdepth 3 -type f 
`cat /sys/kernel/config/usb_gadget/g1/UDC`

Android：

`getprop sys.usb.config 
`getprop sys.usb.state 
`getprop persist.sys.usb.config 
`dmesg | grep -i usb 
`dmesg | grep -i configfs 
`dmesg | grep -i gadget`

Host 端 Linux：

`lsusb lsusb -v 
`dmesg -w ip addr 
`ls /dev/ttyACM*`

ADB 调试：

`adb devices 
`adb kill-server 
`adb start-server`

---

**常见问题**

**1. 插电脑无反应**

可能原因：

`Type-C role 没切到 device 
`UDC 没起来 
`gadget 没绑定 UDC 
`USB cable 只有充电线 
`VBUS/CC 检测异常 
`设备树 USB 节点 disabled`

**2. 有枚举但 ADB 不通**

可能原因：

`sys.usb.config 没包含 
`adb adbd 没启动 
`FunctionFS 没 mount 
`ffs.adb 没被 adbd 打开 
`USB 授权没通过 
`PC 端 adb driver 问题`

**3. MTP 不出现**

可能原因：

`gadget config 没包含 mtp 
`用户空间 mtpd 没启动 
`Windows 驱动异常 
`设备没解锁或权限策略限制`

**4. RNDIS 没网卡**

可能原因：

`host 不支持 
`RNDIS 或驱动没加载 
`gadget 配置错误 
`MAC 地址没设置 
`usb0 没 up 
`DHCP 没启动`

**5. UDC busy**

表现：

`echo xxx > UDC # Device or resource busy`

原因：

`已有 gadget 绑定 没有先 echo "" > UDC 解绑 Android init 正在管理 USB`

---

**面试版总结**

你可以这样回答：

> USB gadget 是 Linux 设备端 USB 框架，用来让 Linux 设备被 PC 等 host 枚举成某种 USB 设备。底层是 UDC driver，中间是 gadget/composite core，上层是 function driver，比如 ADB、MTP、RNDIS、Mass Storage、ACM、HID、UVC、UAC 等。现代系统通常通过 configfs 在 /sys/kernel/config/usb_gadget/ 里创建 gadget、配置 vendor/product id、字符串、configuration 和 functions，最后把 gadget 绑定到 /sys/class/udc/ 里的 UDC。Android 手机插电脑时就是典型 gadget 场景，常见组合是 mtp,adb、rndis,adb。调试时重点看 USB role 是否是 device、UDC 是否存在、gadget 是否绑定、sys.usb.config/state 是否一致，以及 host 端 lsusb/dmesg 是否能看到枚举。