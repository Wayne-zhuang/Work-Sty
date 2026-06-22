
[[MTK]]
## Linux Input 输入子系统完整拓扑架构（分层拓扑 + 原理图 + 流程）

#### 一、整体四层拓扑（从硬件 → 用户应用，自上而下反向阅读）

层级总览

1. **硬件总线层**（最底层）：I2C/SPI/USB/GPIO/ 蓝牙 物理输入硬件
2. **设备驱动层（Input Device）**：TP / 键盘 / 鼠标驱动，核心 `struct input_dev`
3. **Input Core 核心层**：整个子系统中枢，事件分发、设备 / Handler 注册管理
4. **事件处理层（Input Handler）**：evdev/mousedev/keyboard 等，生成 `/dev/input/*`
5. **用户空间层**：App、libinput、X11/Wayland、Android InputManager

![[touch-1.jpeg]]

内核三层核心拓扑图

#### 二、完整全栈拓扑总图（含安卓场景适配，匹配你 ILITEK TP 驱动开发）
![[touch-2.jpeg]]

全栈端到端拓扑（含用户态）

##### 1）底层：硬件 & 总线层

##### 硬件设备：

##### - I2C 电容触摸屏（ILITEK、汇顶 GT）、GPIO 物理按键
##### - USB 鼠标 / 键盘、蓝牙手柄、SPI 触控、PS2 设备
    
    ##### 总线载体：I2C Subsystem、USB HID、SPI、Platform Bus、GPIO

##### **驱动层职责**

##### 1. 硬件上电、中断注册；
##### 2. 中断里读取原始坐标 / 按键电平；
##### 3. 转换为标准 `input_event`，调用 `input_report_*` 上报 Input Core；
##### 4. 分配、填充、注册 `struct input_dev` 到核心层。

##### 2）中间枢纽：Input Core（drivers/input/input.c）

##### **核心作用：发布订阅总线**

##### 1. 维护两张全局链表：
    
    ##### - `input_dev_list`：所有已注册输入设备（TP、键盘、按键）
    ##### - `input_handler_list`：所有事件处理器（evdev、mousedev）
    
##### 2. 自动匹配 `input_dev` 与 `input_handler`，生成桥梁 `struct input_handle`；
##### 3. 收到驱动上报事件后，广播分发给所有匹配成功的 Handler；
##### 4. 提供统一 API：`input_allocate_device` / `input_register_device` / `input_report_key` / `input_sync`。

##### **三大核心数据结构拓扑关系**

##### ![](data:image/svg+xml,%3csvg%20xmlns=%27http://www.w3.org/2000/svg%27%20version=%271.1%27%20width=%27256%27%20height=%27192%27/%3e)![image](https://p26-flow-imagex-sign.byteimg.com/labis/image/6b5ff08b9310adcc556038a2d9ea36c0~tplv-a9rns2rl98-pc_smart_face_crop-v1:512:384.image?lk3s=8e244e95&rcl=2026061812392684AA1BFD8BFA2132C792&rrcfp=cee388b0&x-expires=2097117587&x-signature=pFD8GmYt2b8Va0I07nNZx67dFUw%3D)

##### input_dev / input_handler / input_handle 关系图

##### - `struct input_dev`：描述硬件设备（驱动侧）
##### - `struct input_handler`：描述事件处理器（evdev 等上层）
##### - `struct input_handle`：dev 与 handler 的绑定桥梁，一对多关系（一个 TP 设备可同时给 evdev、按键 handler 分发事件）

##### 3）上层：Input Handler 事件处理层

##### 分两类 Handler：

##### 1. **evdev（现代标准，必用）**
    
    ##### - 生成设备节点：`/dev/input/event0~eventX`
    ##### - 直接透传标准 `input_event` 给用户态，无转换；
    ##### - Linux/Android 应用、libinput、安卓 InputManager 统一读取此节点；
    ##### - 你调试 ILITEK TP 用 `cat /dev/input/event2`、`getevent` 底层就是 evdev。
    
##### 2. 传统兼容 Handler（老旧，逐步淘汰）
    
    ##### - `mousedev`：`/dev/input/mouse0` 鼠标专用
    ##### - `keyboard`：控制台键盘事件
    ##### - `joydev`：游戏手柄
    

##### 4）最顶层：用户空间拓扑

##### PC Linux 场景

##### plaintext

##### ```
##### 应用程序(QT/GTK) ← libinput ← X11/Wayland合成器 ← /dev/input/eventX ← evdev
##### ```

##### Android Genio 平台（你当前 MTK 工控 / 平板场景）

##### plaintext

##### ```
##### APP/Framework InputManagerService → EventHub(读取/dev/input/eventX) → View/触摸分发
##### ```

##### 配套调试工具：`getevent`、`sendevent`、`dumpsys input`，全部基于 evdev 节点。

#### 三、事件完整流转拓扑（以 ILITEK 触摸屏幕为例）

1. 手指按压 TP → I2C 硬件产生中断；
2. ilitek_plat_dev_init 注册的中断服务函数读取坐标；
3. 驱动调用 `input_report_abs()` 上报 X/Y 坐标、`input_report_key()` 上报按下 / 抬起；
4. `input_sync()` 同步一次完整帧事件，提交 Input Core；
5. Input Core 遍历所有绑定的 handler（evdev）；
6. evdev 将事件放入字符设备缓冲区；
7. 用户态 `getevent` / Android EventHub read `/dev/input/eventX` 获取标准触摸事件；
8. 框架分发给上层 APP 响应触摸操作。

#### 四、关键区分（对应你之前代码 `module_init / late_initcall`）

- ILITEK TP 驱动属于 **Input Device 驱动层**，编译为 `.ko` 则通过 `module_init` 注册 `input_dev`；
- 若编译内置 = y 走 `late_initcall`，内核早期直接注册输入设备；
- 无论哪种加载方式，最终都注册到 Input Core，由 evdev 统一暴露节点给用户态。

#### 五、简化文字拓扑树

plaintext

```
【用户空间应用层】
    ├─ Android InputManager / getevent
    └─ X11/Wayland / libinput
           ↓ read /dev/input/eventX
【Handler事件处理层】
    ├─ evdev (主流标准)
    ├─ mousedev / joydev / keyboard (兼容)
           ↓ 事件分发
【Input Core 核心中枢】
    ├─ input_dev_list 设备链表
    └─ input_handler_list 处理器链表
           ↓ 上报标准input_event
【设备驱动层】
    ├─ I2C Touch驱动(ilitek)
    ├─ USB鼠标/键盘驱动
    └─ GPIO按键驱动
           ↓ 硬件中断/数据读取
【硬件总线层】
    I2C / SPI / USB / Bluetooth / GPIO
```


## 怎样初步检查 TouchPanel 驱动是否正常工作

**[DESCRIPTION]**

使用 adb shell getevent 命令检查 TouchPanel是否正常工作

**[KEYWORD]**

touch panel

**[SOLUTION]**

1. 使用如下命令找出 mtk-tpd 对应的event设备

  adb shell get event -i

2. 使用此设备读取 TouchPanel上报的事件：

  adb shell get event /dev/input/event3

每一行有三个数值，通过查询input.h，可以得到其含义，举例如下：

|   |   |   |
|---|---|---|
|**type**|**code**|**value**|
|1=EV_KEY|0x14a(330) = BTN_TOUCH|Down=1， Up=0|
|3=EV_ABS|0x30(48)   = ABS_MT_TOUCH_MAJOR|1|
|3=EV_ABS|0x35(53)   = ABS_MT_POSITION_X|x=284|
|3=EV_ABS|0x36(54)   = ABS_MT_POSITION_Y|y=366|
|3=EV_ABS|0x39(57)   = ABS_MT_TRACKING_ID|point index=1|
|0=EV_SYN|0x2(2)     = SYN_MT_REPORT|0|
|0=EV_SYN|0x0(0)     = SYN_REPORT|0|

## 从手指按下到 App 收到 `MotionEvent`的流程

#### A. 硬件与中断入口

- •
    手指接近屏幕，触摸 IC（如 OVT/Goodix/FocalTech）完成电容矩阵扫描，生成一帧 report。
    
    IC 通过 `INT` 引脚拉中断给 SoC。
    
    内核驱动中断线程被唤醒（常见是 `irq handler -> threaded irq`）。

#### B. 驱动收包与解析（你之前看的重点）

- •
    
    驱动从总线（I2C/SPI）读取报文头 + payload。
    
    
    将 payload 放入内部 buffer，并根据 `report id` 分流：
    
        
        TOUCH report`：解析触点数量、每点 x/y、压力、状态（down/move/up）；
        
        
        `FW printf/report`：做调试日志打印；
        
            
        `identify/config report`：触发 reinit 或模块同步。
        
    
    
    你看到的 `dispatch_report` 这类函数，本质就是“按 report 类型做分发”。
    

#### C. 上报 Linux Input 子系统

- •
    
    驱动通过 `input_report_abs()` / `input_mt_*()` / `input_sync()` 上报到 input core。
    
- •
    
    形成标准事件流：`EV_ABS` + `ABS_MT_POSITION_X/Y` + `SYN_REPORT`。
    
- •
    
    用户态可在 `/dev/input/event*` 看到触摸事件。
    

#### D. Android 输入管线

- •
    
    `InputReader` 读取 `event*`，识别为 touch device。
    
- •
    
    `InputDispatcher` 按焦点窗口分发。
    
- •
    
    应用层收到 `MotionEvent`（View 的 `onTouchEvent`）。
    

#### E. 触摸在休眠/唤醒时做什么

典型动作：

- •
    
    Suspend：
    
    - •
        
        驱动停普通触摸扫描；
        
    - •
        
        可切到 gesture/doze 模式（如果支持双击唤醒等）；
        
    - •
        
        关/降中断处理路径、降功耗。
        
    
- •
    
    Resume：
    
    - •
        
        重新上电/复位 IC（有些平台会 reset pin 切换）；
        
    - •
        
        重写关键寄存器/配置（灵敏度、滤波、手势开关）；
        
    - •
        
        清状态，重新使能中断；
        
    - •
        
        必要时做一次“identify + reinit”确保 FW/配置一致。
        
    

#### F. 触摸链路常见问题（你最可能遇到）

- •
    
    唤醒后无触摸：resume 时序错、reset 后配置没重写、中断未重开。
    
- •
    
    充电时触摸漂移：噪声场景参数没切换、抗干扰策略没生效。
    
- •
    
    偶发断触：irq 风暴/丢中断、report 长度校验失败、buffer 并发锁问题。
    
- •
    
    固件：跑在触摸 IC 内部 MCU 上，负责“感知与算法”。
    
- •
    
    驱动：跑在 Linux/Android 内核里，负责“通信、控制、上报系统事件”。
    
- •
    
    二者关系：驱动不是替代固件，而是通过 I2C/SPI 与固件交互，把 FW 计算结果送到系统输入框架。
    

---

#### 驱动和固件如何配合的？

- •
    
    固件：跑在触摸 IC 内部 MCU 上，负责“感知与算法”。
    
- •
    
    驱动：跑在 Linux/Android 内核里，负责“通信、控制、上报系统事件”。
    
- •
    
    二者关系：驱动不是替代固件，而是通过 I2C/SPI 与固件交互，把 FW 计算结果送到系统输入框架。
    

触摸固件负责：

- •
    
    传感矩阵扫描（Tx/Rx）
    
- •
    
    原始信号处理（滤波、去噪、基线跟踪）
    
- •
    
    触点识别与跟踪（坐标、手指数、轨迹）
    
- •
    
    手势识别（双击唤醒等，若支持）
    
- •
    
    场景策略（充电噪声、手套模式、湿手等）
    
- •
    
    自检/校准/温漂补偿
    
- •
    
    对外输出 report 数据格式
    

所以你可以把固件看成“触摸算法引擎 + 实时控制器”。

---

驱动负责

驱动通常负责：

- •
    
    中断处理与收包（从 IC 读 report）
    
- •
    
    解析协议帧（report id、payload）
    
- •
    
    下发控制命令（开关手势、灵敏度、模式切换）
    
- •
    
    suspend/resume 时序控制（睡眠、唤醒、重初始化）
    
- •
    
    FW 升级流程（下载、校验、版本判断）
    
- •
    
    通过 Linux input 上报给 Android（`event` 节点）
    

驱动更像“系统适配层 + 通信控制层”。


两者关系（最关键）

可以用一句话概括：

固件决定“触摸怎么感知和计算”，驱动决定“系统怎么拿到结果并管控它”。

调用链（简化）

`手指 -> IC固件算法 -> report -> 内核驱动解析 -> input子系统 -> Android MotionEvent`


常见误区
    
    误区1：驱动改了就能修所有触摸问题
        
        错。很多“漂移/鬼点/边缘手感”问题根因在 FW 参数或算法。
    
    误区2：FW 升级只影响精度，不影响稳定性
        
        错。FW 还影响中断频率、report 时序、休眠唤醒行为。
    
    误区3：驱动和 FW 可以随便混搭
        
        错。协议版本、report 格式、命令集不一致会出大问题。


## TP问题分析步骤

1、使用OTG看是否时死机还是TP无触？

2、使用OTG输入*#9375#，看下能否读到TP信息？

3、休眠唤醒是否能恢复？

4、重启机器是否能恢复？

5、和OK的机器交叉模组，看是否跟着模组走？

6、复现问题，抓取开机的log给研发分析

能读到信息，说明供电和I2C，reset是通的，怀疑是中断pin断了。

tp引脚：vdd tp供电，

reset 复位引脚，

Eint 中断引脚，

scl sda i2c接口。

上电后通过RESET脚控制TP芯片复位；

通过I2C接口给TP设置参数或读取TP数据；

TP有触摸操作时通过EINT脚通知主控；

情况一：中断信号正常，需要确认i2c通信是否正常。目前基本没有i2c通信失败的，问题基本在数据处理并进行上报部分，一般起一个单线程，需要具体分析线程回调函数中的代码部分。

情况二：没有中断信号，需要确认中断和复位的gpio号在probe中是否获取到；确认gpio是否和硬件原理图中的gpio号一致；确认6个引脚的默认电压是否正常，触摸后电压高低变化是否满足要求，

（排除是否硬件问题。ctp初始化时都会做复位操作，通过交替拉高拉低复位脚和中断脚，这部分需要同fea确认代码的流程是否满足datasheet中ic复位要求，如拉引脚的顺序和必须的延迟时间。

分析代码中的中断打开关闭逻辑是否存在问题，中断中是否有调用会睡眠的函数）；

情况三：i2c通信正常，中断正常，触摸无数据，则需要fea配合针对本项目调试tp固件，未经过调试的固件很可能产生此现象。

ctp的bug涉及三个层面：驱动代码部分、固件部分和硬件模组部分。三个层面分工：固件部分需要依靠fae现场支持进行调试、驱动部分需要我们定位解决、模组问题需要模组厂分析。

TP 响应用户的操作原理，就是当用户点击屏幕进行操作的时候，会产生中断。通过

和 BaseBand 连接的中断引脚触发 BaseBand 去 TP 的寄存器去

读点。然后将点进行判断数据是否有效有效就进行处理，再通过input上报。

## Getevent 使用

adb shell getevent

查看某个设备的详细信息

adb shell getevent -p /dev/input/event1

示例：

events:

KEY (0001): 0072 0073 0074

ABS (0003): ABS_X value 0, min 0, max 720

实时监听触摸屏事件（带标签和时间戳）

adb shell getevent -lt /dev/input/event2

输出示例：

[ 1234.567890] EV_ABS ABS_MT_POSITION_X 000001f4

[ 1234.567890] EV_ABS ABS_MT_POSITION_Y 00000320

[ 1234.567890] EV_SYN SYN_REPORT 00000000

查看某一个事件触发

adb shell getevent -lt /dev/input/eventx

示例：只监控电源键的按下/抬起

adb shell getevent -lt /dev/input/event1 | grep KEY_POWER

只监控触摸屏的 X 坐标变化

adb shell getevent -lt /dev/input/event2 | grep ABS_MT_POSITION_X

查看报点率

getevent -ltr

- 录制操作：将 getevent 输出保存为脚本，配合 sendevent 实现自动化回放。
- 调试输入问题：查看某个设备是否注册成功、是否发出预期事件。
- 分析多点触控：使用 -lt 参数观察 ABS_MT_SLOT、ABS_MT_TRACKING_ID 等字段。

✅ 注意事项

- 某些设备需要 root 权限才能访问 /dev/input/ 下的设备节点。
- 时间戳为 CLOCK_MONOTONIC，不是系统实时时间。
- 输出为十六进制，需注意转换。