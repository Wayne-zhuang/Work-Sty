
Linux 内核里的“子系统”可以理解为：把不同类型的硬件、资源和内核能力分门别类管理的一组框架。驱动通常不是孤立存在的，而是挂到某个子系统里，比如触摸屏驱动一般属于 input 子系统，同时还可能依赖 i2c、gpio、pinctrl、regulator、irq、power management 等子系统。

常见子系统如下。

**进程调度**  
负责线程/进程的运行、抢占、CPU 时间分配、负载均衡。  
典型代码目录：kernel/sched/

**内存管理**  
管理物理内存、虚拟内存、页表、slab/slub、vmalloc、DMA 内存、OOM 等。  
典型目录：mm/

**VFS 文件系统**  
提供统一的文件访问接口，屏蔽 ext4、f2fs、procfs、sysfs、tmpfs 等具体文件系统差异。  
典型目录：fs/

**块设备子系统**  
管理 eMMC、UFS、NVMe、SD 卡、硬盘等按块读写的设备，负责请求队列、IO 调度等。  
典型目录：block/、drivers/mmc/、drivers/ufs/

**字符设备**  
面向按字节流或 ioctl 访问的设备，比如 tty、misc、部分传感器节点等。  
常见接口：register_chrdev()、misc_register()

**设备模型 / Driver Model**  
Linux 驱动的核心框架，管理 device、driver、bus、class、probe/remove、sysfs 节点等。  
典型目录：drivers/base/

**总线子系统**  
用于把设备和驱动匹配起来。常见总线包括：

- platform：SoC 内部设备，很多手机外设都走它
- i2c：触摸 IC、PMIC、摄像头 EEPROM、传感器常用
- spi：触摸、指纹、屏幕、flash 等可能使用
- usb：USB host/device
- pci：PC/服务器常见
- serdev：串口挂载设备

你的 ILITEK 触摸驱动一般会和 i2c 或 spi 子系统强相关。

**Input 输入子系统**  
管理触摸屏、按键、鼠标、键盘、触控板等输入设备。驱动上报事件，用户空间通过 /dev/input/eventX 读取。  
常见接口：

`input_allocate_device(); input_register_device(); input_report_abs(); input_report_key(); input_mt_slot(); input_mt_report_slot_state(); input_sync();`

你当前看的触摸屏驱动主要就是挂在这个子系统下面。

**中断子系统**  
管理硬件 IRQ、中断线程化、软中断、tasklet、workqueue 等。  
触摸屏通常通过 GPIO IRQ 通知有触摸数据。

常见接口：

`request_irq(); devm_request_threaded_irq(); enable_irq(); disable_irq();`

**GPIO 子系统**  
管理 GPIO 输入输出、中断映射等。  
触摸屏常用 GPIO 包括 reset-gpio、irq-gpio。

常见接口：

`gpiod_get(); gpiod_set_value(); gpio_to_irq();`

**Pinctrl 子系统**  
管理管脚复用和电气状态，比如 active/sleep 状态、上下拉、驱动强度。  
手机平台里很常见，设备树里常见：

`pinctrl-names = "default", "sleep"; pinctrl-0 = <...>; pinctrl-1 = <...>;`

**Regulator 电源子系统**  
管理 LDO、BUCK、电源 rail。触摸 IC 经常需要 vdd、iovdd。  
常见接口：

`regulator_get(); regulator_enable(); regulator_disable();`

**Clock 时钟子系统**  
管理 SoC 内各种 clock gate、PLL、频率切换。  
常见于 display、camera、audio、storage、network 驱动。

**Reset 子系统**  
管理硬件 reset line。部分 SoC 外设会使用 reset controller，而不是普通 GPIO reset。

**DMA 子系统**  
管理直接内存访问，减少 CPU 搬运数据。常见于音频、显示、摄像头、网络、存储。

**网络子系统**  
管理网卡、协议栈、socket、路由、防火墙等。  
典型目录：net/、drivers/net/

**TTY / 串口子系统**  
管理串口、控制台、蓝牙 UART、modem 通道等。  
典型目录：drivers/tty/

**USB 子系统**  
管理 USB host、USB gadget、Type-C、PD 等。  
典型目录：drivers/usb/

**音频子系统 ALSA / ASoC**  
手机和嵌入式设备主要用 ASoC，管理 codec、platform、machine driver、DAI、DAPM 等。  
典型目录：sound/soc/

**显示子系统 DRM / Framebuffer**  
现代 Linux 主要使用 DRM/KMS，管理显示控制器、panel、bridge、GPU、composition 等。  
Android 平台也可能有厂商私有 display 框架。  
典型目录：drivers/gpu/drm/、drivers/video/

**摄像头 / Media 子系统**  
管理 camera sensor、ISP、MIPI CSI、V4L2、media graph。  
典型目录：drivers/media/

**电源管理**  
包括 suspend/resume、runtime PM、wakeup source、CPU idle、thermal、充电等。  
触摸屏常涉及：

`suspend(); resume(); device_init_wakeup(); pm_wakeup_event();`

**Thermal 热管理子系统**  
管理温度传感器、降频、关机保护、cooling device。  
典型目录：drivers/thermal/

**LED / Backlight 子系统**  
管理 LED、闪光灯、LCD 背光等。  
典型目录：drivers/leds/、drivers/video/backlight/

**RTC 子系统**  
管理实时时钟、闹钟唤醒。  
典型目录：drivers/rtc/

**Watchdog 子系统**  
系统卡死时自动复位。  
典型目录：drivers/watchdog/

**安全子系统**  
包括 LSM、SELinux、AppArmor、capability、seccomp 等。Android 上 SELinux 很关键。  
典型目录：security/

**调试与跟踪**  
包括 printk、tracepoint、ftrace、perf、debugfs、procfs、sysfs、kprobe 等。  
驱动调试时常用：

`dmesg cat /proc/interrupts cat /proc/bus/input/devices getevent trace-cmd`

结合你现在看的 ILITEK 触摸驱动，最相关的是：

`Input 子系统 上报触摸点、按键、手势 I2C/SPI 子系统 和触摸 IC 通信 GPIO 子系统 reset、irq 管脚 IRQ 子系统 触摸中断处理 Pinctrl 子系统 管脚状态切换 Regulator 子系统 触摸 IC 上下电 PM 子系统 suspend/resume、手势唤醒 Device Tree 描述硬件资源 Sysfs/Procfs 暴露调试节点 Workqueue/Mutex 异步处理和并发保护 Firmware 子系统 加载触摸 IC 固件，若驱动支持`

所以你读触摸驱动时，可以按这个顺序看：

1. i2c_driver / spi_driver 的 probe
2. 解析设备树：GPIO、电源、pinctrl、panel 信息
3. 上电和 reset 流程
4. 注册 input device
5. 申请 IRQ
6. 中断里读取触摸数据
7. 通过 input 子系统上报坐标
8. suspend/resume 和手势唤醒
9. firmware upgrade / proc 或 sysfs 调试接口