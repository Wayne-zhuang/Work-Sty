
[[Linux 子系统汇总]]


**1. Input 子系统解决什么问题**

Input 子系统是 Linux 内核中统一管理输入设备的框架，典型设备包括：

- 键盘
- 鼠标
- 触摸屏
- 触控板
- 按键
- 旋钮
- 游戏手柄
- Hall、耳机按键、指纹按键等

它的目标是把不同硬件的输入行为抽象成统一事件。

驱动不用自己创建设备节点、定义用户空间协议，而是把事件上报给 Input core。  
Input core 再通过 evdev 等 handler 暴露给用户空间，最终形成：

`/dev/input/event0 /dev/input/event1 /dev/input/event2 ...`

Android/Linux 用户空间通过这些节点读取输入事件。

---

**2. Input 子系统整体架构**

可以从三层理解：

`硬件设备 ↓ 具体 input driver ↓ Input core ↓ Input handler，例如 evdev、mousedev、kbd ↓ /dev/input/eventX ↓ 用户空间：getevent、InputReader、libinput、X/Wayland`

其中核心角色有三个：

`input_dev 表示一个输入设备 input_handler 表示一种事件消费者，例如 evdev input_handle 连接 input_dev 和 input_handler`

驱动一般只直接关心 struct input_dev。

---

**3. 关键数据结构：struct input_dev**

struct input_dev 表示一个输入设备。  
比如一个触摸屏、一个按键矩阵、一个触控板，通常都会对应一个 input_dev。

驱动常见初始化流程：

`struct input_dev *input; input = input_allocate_device(); input->name = "ilitek touch"; input->id.bustype = BUS_I2C; set_bit(EV_ABS, input->evbit); set_bit(EV_KEY, input->evbit); set_bit(BTN_TOUCH, input->keybit); input_set_abs_params(input, ABS_MT_POSITION_X, 0, x_max, 0, 0); input_set_abs_params(input, ABS_MT_POSITION_Y, 0, y_max, 0, 0); input_register_device(input);`

如果使用 devm_ 版本，资源释放会更自动：

`input = devm_input_allocate_device(dev); input_register_device(input);`

面试可以说：  
input_dev 里保存了设备能力位图、事件位图、绝对坐标范围、设备名称、bus 类型、open/close 回调等信息。

---

**4. Input 事件模型**

Input 子系统使用统一的事件格式：

`struct input_event { struct timeval time; __u16 type; __u16 code; __s32 value; };`

常见事件类型：

`EV_KEY 按键类事件 EV_REL 相对坐标事件，比如鼠标移动 EV_ABS 绝对坐标事件，比如触摸屏坐标 EV_SYN 同步事件，表示一组事件结束 EV_SW 开关类事件，比如 Hall EV_MSC 杂项事件 EV_LED LED 状态 EV_FF 力反馈`

常见 code：

`KEY_POWER 电源键 KEY_VOLUMEUP 音量加 BTN_TOUCH 触摸按下 ABS_X / ABS_Y 单点绝对坐标 ABS_MT_POSITION_X 多点触摸 X 坐标 ABS_MT_POSITION_Y 多点触摸 Y 坐标 ABS_MT_TRACKING_ID 多点触摸 tracking id ABS_MT_PRESSURE 压力 ABS_MT_TOUCH_MAJOR 触摸面积`

一次完整上报通常以 input_sync() 结束：

`input_report_key(input, BTN_TOUCH, 1); input_report_abs(input, ABS_X, x); input_report_abs(input, ABS_Y, y); input_sync(input);`

input_sync() 会产生 EV_SYN / SYN_REPORT，告诉用户空间这一帧事件结束。

---

**5. 用户空间如何看到事件**

注册成功后，内核会通过 evdev 创建设备节点：

`/dev/input/eventX`

可以用这些命令看：

`cat /proc/bus/input/devices getevent -l getevent -lt /dev/input/eventX hexdump /dev/input/eventX`

Android 上常用：

`adb shell getevent -lp adb shell getevent -lt adb shell dumpsys input`

getevent -lp 可以看到设备支持哪些事件、坐标范围、按键能力。

---

**6. 驱动接入 Input 子系统的标准流程**

以触摸屏驱动为例，典型流程是：

`probe ↓ 申请/初始化私有结构体 ↓ 解析 dts：irq gpio、reset gpio、坐标范围、电源 ↓ 上电、reset、读取 chip id ↓ 申请 input_dev ↓ 设置 input_dev 能力 ↓ 注册 input_dev ↓ 申请 irq ↓ 中断触发后读取触摸数据 ↓ input_report_* 上报 ↓ input_sync`

伪代码：

`static int xxx_ts_probe(struct i2c_client *client) { struct input_dev *input; input = devm_input_allocate_device(&client->dev); if (!input) return -ENOMEM; input->name = "xxx-touchscreen"; input->id.bustype = BUS_I2C; input_set_capability(input, EV_KEY, BTN_TOUCH); input_set_abs_params(input, ABS_MT_POSITION_X, 0, x_max, 0, 0); input_set_abs_params(input, ABS_MT_POSITION_Y, 0, y_max, 0, 0); input_mt_init_slots(input, max_touch_num, INPUT_MT_DIRECT); error = input_register_device(input); if (error) return error; error = devm_request_threaded_irq(...); if (error) return error; return 0; }`

---

**7. 多点触摸协议：重点面试内容**

触摸屏面试里，MT 多点触摸协议经常会问。

Linux Input 多点触摸主要有两种协议：

`Type A：旧协议，逐点上报，不使用 slot Type B：新协议，使用 slot，主流触摸屏都用 Type B`

现在 Android 触摸屏驱动一般使用 **Type B slot 协议**。

核心概念：

`slot 一个触点槽位 tracking id 标识一次手指生命周期 active/inactive 该 slot 当前是否有手指`

典型上报流程：

`input_mt_slot(input, id); input_mt_report_slot_state(input, MT_TOOL_FINGER, true); input_report_abs(input, ABS_MT_POSITION_X, x); input_report_abs(input, ABS_MT_POSITION_Y, y); input_report_abs(input, ABS_MT_PRESSURE, pressure);`

手指离开时：

`input_mt_slot(input, id); input_mt_report_slot_state(input, MT_TOOL_FINGER, false);`

一帧结束：

`input_mt_sync_frame(input); input_sync(input);`

完整例子：

`for (i = 0; i < touch_num; i++) { input_mt_slot(input, points[i].id); input_mt_report_slot_state(input, MT_TOOL_FINGER, true); input_report_abs(input, ABS_MT_POSITION_X, points[i].x); input_report_abs(input, ABS_MT_POSITION_Y, points[i].y); input_report_abs(input, ABS_MT_PRESSURE, points[i].pressure); } input_mt_sync_frame(input); input_sync(input);`

面试回答可以强调：

> Type B 协议用 slot 保存每个触点状态，减少重复上报，也让用户空间更容易跟踪每根手指的生命周期。

---

**8. input_set_abs_params 的作用**

触摸屏必须告诉 input core 坐标范围：

`input_set_abs_params(input, ABS_MT_POSITION_X, 0, 720, 0, 0); input_set_abs_params(input, ABS_MT_POSITION_Y, 0, 1600, 0, 0);`

参数含义：

`input_set_abs_params(dev, axis, min, max, fuzz, flat);`

含义：

`min 最小值 max 最大值 fuzz 抖动过滤容忍值 flat 死区，常用于摇杆`

用户空间会根据这个范围做坐标映射。  
如果范围错了，可能出现触摸偏移、比例不对、边缘点不到等问题。

---

**9. input_sync 为什么重要**

input_report_*() 只是把事件放入 input 子系统。  
input_sync() 表示一组事件完成。

例如触摸屏一帧可能包含多个点：

`slot 0 x y pressure slot 1 x y pressure slot 2 x y pressure SYN_REPORT`

用户空间看到 SYN_REPORT 后，才认为这一帧完整。

如果漏掉 input_sync()，用户空间可能收不到完整事件，表现为触摸无响应或事件异常。

---

**10. 和中断线程的关系**

Input 子系统本身不负责从硬件取数据。  
硬件数据通常由中断触发：

`触摸 IC 拉低/拉高 IRQ ↓ 内核进入 irq handler/threaded irq ↓ 驱动通过 I2C/SPI 读取坐标数据 ↓ 解析点数、id、x、y、pressure ↓ 调用 input_report_*() ↓ input_sync()`

触摸屏一般使用 threaded irq，因为 I2C/SPI 读取可能睡眠，不能放在硬中断里做。

典型形式：

`devm_request_threaded_irq(dev, irq, NULL, xxx_irq_thread, IRQF_ONESHOT | IRQF_TRIGGER_FALLING, "xxx_ts", ts);`

面试可答：

> 硬中断里不做 I2C 通信，使用 threaded irq，在中断线程里读取触摸数据并上报 input 事件。

---

**11. open / close 回调**

input_dev 可以设置：

`input->open = xxx_input_open; input->close = xxx_input_close;`

当用户空间打开 /dev/input/eventX 时，open 被调用；最后一个用户关闭时，close 被调用。

可以用于：

`enable irq enable power 启动设备 停止设备 降低功耗`

但很多 Android 触摸屏驱动不完全依赖 open/close，而是通过 suspend/resume 管理功耗。

---

**12. suspend / resume 中 Input 的角色**

触摸屏驱动常见需求：

`灭屏后关闭触摸 灭屏后保留手势唤醒 亮屏后恢复正常报点`

如果支持手势唤醒：

`suspend: 进入 gesture mode enable_irq_wake() 保持部分电源 resume: disable_irq_wake() reset 或切回 normal mode 恢复报点`

Input 子系统负责上报唤醒按键，例如：

`input_report_key(input, KEY_POWER, 1); input_sync(input); input_report_key(input, KEY_POWER, 0); input_sync(input);`

或者上报厂商定义的 gesture key。

---

**13. Android 输入链路**

Android 上触摸事件路径可以这样讲：

`Touch IC ↓ IRQ Kernel touch driver ↓ input_report_abs/input_sync Input core ↓ evdev /dev/input/eventX ↓ EventHub ↓ InputReader ↓ InputDispatcher ↓ Window / View`

调试路径：

`adb shell getevent -lt adb shell getevent -lp adb shell dumpsys input adb shell dumpsys window`

如果 getevent 有事件但 UI 没反应，问题可能在 Android input 配置、坐标映射、display id、窗口焦点等。  
如果 getevent 没事件，优先查驱动、中断、I2C、input 注册。

---

**14. 常见问题和排查思路**

**问题 1：没有 /dev/input/eventX**

排查：

`input_register_device 是否成功 probe 是否执行 驱动是否匹配 dts compatible 是否返回错误 内核 log 是否有 input device 注册信息`

命令：

`cat /proc/bus/input/devices dmesg | grep -i input dmesg | grep -i ilitek`

**问题 2：有 event 节点，但没有触摸事件**

排查：

`IRQ 是否触发 /proc/interrupts 计数是否增加 I2C/SPI 读数据是否成功 触摸 IC 是否在正常模式 是否被 suspend 是否 disable_irq`

命令：

`cat /proc/interrupts getevent -lt /dev/input/eventX`

**问题 3：坐标反了、偏了、比例不对**

排查：

`ABS_MT_POSITION_X/Y min max 是否正确 dts 里 panel 分辨率是否正确 是否需要 swap-x-y 是否需要 invert-x / invert-y Android .idc 配置是否影响映射`

**问题 4：多指异常**

排查：

`slot id 是否稳定 抬手时是否上报 false 是否调用 input_mt_sync_frame 是否调用 input_sync max touch number 是否正确`

---

**15. 面试高频问题**

**问：Input 子系统中 input_dev、input_handler、input_handle 的关系？**

答：

`input_dev 表示输入设备，比如触摸屏。 input_handler 表示事件处理者，比如 evdev。 input_handle 是两者之间的连接。 当 input_dev 注册后，input core 会和匹配的 handler 建立 handle。 evdev handler 会创建设备节点 /dev/input/eventX。`

**问：input_report_abs 和 input_sync 的关系？**

答：

`input_report_abs 上报具体事件值，比如坐标。 input_sync 表示一组事件结束，会生成 SYN_REPORT。 用户空间通常以 SYN_REPORT 作为一帧输入事件的边界。`

**问：触摸屏为什么使用 EV_ABS？**

答：

`触摸屏上报的是屏幕上的绝对坐标，不是相对位移。 所以使用 EV_ABS 和 ABS_MT_POSITION_X/Y。 鼠标移动一般使用 EV_REL。`

**问：Type A 和 Type B 多点协议区别？**

答：

`Type A 不使用 slot，每一帧顺序上报所有触点。 Type B 使用 slot，每个 slot 表示一个触点状态，并通过 tracking id 跟踪生命周期。 Type B 更高效，也是现在多点触摸屏主流方式。`

**问：为什么触摸屏 IRQ 通常用 threaded irq？**

答：

`因为中断后通常需要通过 I2C/SPI 读取触摸数据。 I2C/SPI 传输可能睡眠，不能在硬中断上下文执行。 所以使用 threaded irq，把读取和上报放到中断线程里。`

**问：Android 触摸事件从内核到 App 的路径？**

答：

`Touch IC -> IRQ -> kernel touch driver -> input core -> evdev -> /dev/input/eventX -> EventHub -> InputReader -> InputDispatcher -> App Window/View`

---

**16. 结合你这个 ILITEK 驱动应该重点看哪里**

你现在看的 ILITEK 触摸驱动，可以重点找这些函数或关键字：

`input_allocate_device devm_input_allocate_device input_register_device input_set_abs_params input_mt_init_slots input_mt_slot input_mt_report_slot_state input_report_abs input_report_key input_sync request_threaded_irq`

在文件上大概率分布是：

`ilitek_v3_i2c.c i2c driver、probe、remove ilitek_v3.c 初始化主流程、input 注册、资源申请 ilitek_v3_touch.c 触摸数据解析和 input 上报 ilitek_v3_qcom.c 平台相关、电源、pinctrl、panel/通知链等 ilitek_v3_flash.c 固件升级，不是 input 主链路`

如果面试官让你结合项目讲，可以这样总结：

> 我做的触摸驱动属于 Linux Input 子系统。驱动在 probe 阶段解析设备树、初始化电源和 GPIO、注册 input_dev，并通过 input_set_abs_params 设置触摸坐标范围，通过 input_mt_init_slots 初始化多点触摸 slot。触摸 IC 中断触发后，驱动在线程化中断里通过 I2C 读取坐标数据，解析每个触点的 id、x、y、pressure，然后用 input_mt_slot、input_mt_report_slot_state、input_report_abs 上报，最后调用 input_mt_sync_frame 和 input_sync 形成一帧事件。用户空间通过 evdev 生成的 /dev/input/eventX 获取事件，Android 再由 EventHub、InputReader、InputDispatcher 分发给 App。