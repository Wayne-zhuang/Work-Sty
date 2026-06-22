
[[Linux 子系统汇总]][[GPIO子系统]]

**Pinctrl 子系统是什么**

Pinctrl 是 Linux 里管理 SoC 管脚配置的子系统。  
它主要负责两类事情：

`1. Pin mux：管脚复用 决定一个 pin 当前用作 GPIO、I2C、SPI、UART、PWM，还是其他外设功能。 2. Pin config：管脚电气属性 配置上下拉、驱动强度、输入使能、输出电平、Schmitt trigger、slew rate 等。`

一句话：

> GPIO 负责“这个脚作为 GPIO 时怎么读写电平”，Pinctrl 负责“这个物理 pin 当前是什么功能、有什么电气配置”。

---

**为什么需要 Pinctrl**

SoC 的一个物理管脚通常不只一种功能，比如：

`Pin 12 可以是： GPIO12 I2C1_SDA SPI0_MOSI UART2_TX PWM3`

驱动不能只申请 GPIO，还必须保证这个 pin 已经被配置到正确功能。  
比如触摸屏：

`reset pin 需要配置成 GPIO output irq pin 需要配置成 GPIO input + pull-up/pull-down i2c pins 需要配置成 I2C SDA/SCL function spi pins 需要配置成 SPI function`

这些都属于 pinctrl 的职责。

---

**Pinctrl 和 GPIO 的区别**

面试里很容易问这个。

`Pinctrl： 管脚复用和电气属性配置。 例如把 pin 设置成 GPIO 模式、I2C 模式、上拉、下拉、驱动能力。 GPIO： 当 pin 已经处于 GPIO 模式后，控制它输入、输出、读值、写值、转 IRQ。`

例子：

`如果 reset 脚 pinmux 没切到 GPIO， 即使 gpiod_set_value(reset_gpio, 1)，实际管脚也可能没有变化。 如果 irq 脚没有配置输入和上拉， 中断可能不触发，或者容易误触发。`

---

**Pinctrl 子系统架构**

可以这样理解：

`SoC pin controller driver ↓ Pinctrl core ↓ 设备树 pinctrl 配置 ↓ 具体外设驱动选择 pin state`

核心对象：

`pinctrl_dev 表示一个 pin controller pinctrl_state 表示一组 pin 配置状态 pinctrl 某个设备拥有的 pinctrl 句柄`

驱动常见 API：

`struct pinctrl *pinctrl; struct pinctrl_state *pins_default; struct pinctrl_state *pins_sleep; pinctrl = devm_pinctrl_get(dev); pins_default = pinctrl_lookup_state(pinctrl, "default"); pins_sleep = pinctrl_lookup_state(pinctrl, "sleep"); pinctrl_select_state(pinctrl, pins_default); pinctrl_select_state(pinctrl, pins_sleep);`

---

**设备树里的 Pinctrl**

设备树里通常分两部分：

第一部分：设备节点引用 pinctrl 状态。

`touchscreen@41 { compatible = "ilitek,ili9881h"; reg = <0x41>; pinctrl-names = "default", "sleep"; pinctrl-0 = <&tp_default>; pinctrl-1 = <&tp_sleep>; reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>; };`

第二部分：在 pin controller 节点里定义具体配置。

不同平台写法不一样。以概念为例：

`tp_default: tp_default { pins = "gpio12", "gpio13"; function = "gpio"; bias-pull-up; drive-strength = <8>; }; tp_sleep: tp_sleep { pins = "gpio12", "gpio13"; function = "gpio"; bias-pull-down; drive-strength = <2>; };`

MTK 平台设备树写法经常会更像：

`tp_irq_default: tp_irq_default { pins_cmd_dat { pinmux = <PINMUX_GPIO13__FUNC_GPIO13>; bias-pull-up; input-enable; }; }; tp_rst_default: tp_rst_default { pins_cmd_dat { pinmux = <PINMUX_GPIO12__FUNC_GPIO12>; output-high; }; };`

具体属性名取决于平台 pinctrl driver binding。

---

**pinctrl-names 和 pinctrl-0 的关系**

这个是设备树常考点。

`pinctrl-names = "default", "sleep"; pinctrl-0 = <&tp_default>; pinctrl-1 = <&tp_sleep>;`

含义是：

`"default" 对应 pinctrl-0 "sleep" 对应 pinctrl-1`

驱动里：

`state = pinctrl_lookup_state(pinctrl, "default");`

找到的就是 pinctrl-0 对应的 tp_default。

`state = pinctrl_lookup_state(pinctrl, "sleep");`

找到的就是 pinctrl-1 对应的 tp_sleep。

如果名字写错，比如设备树叫 "pmx_ts_active"，驱动查 "default"，就会查不到。

---

**Default 状态**

很多设备驱动不显式调用：

`pinctrl_select_state(pinctrl, pins_default);`

但设备 probe 时，内核设备模型可能会自动选择 "default" 状态。

不过在驱动里显式管理更清楚，尤其是需要 suspend/resume 切换时：

`static int xxx_ts_resume(struct device *dev) { pinctrl_select_state(ts->pinctrl, ts->pins_default); return 0; } static int xxx_ts_suspend(struct device *dev) { pinctrl_select_state(ts->pinctrl, ts->pins_sleep); return 0; }`

---

**触摸屏里 Pinctrl 常见状态**

触摸屏常见状态：

`default / active： reset pin 配成 GPIO output irq pin 配成 GPIO input irq pin 配置合适的上拉/下拉 I2C/SPI pin 配成对应复用功能 驱动强度正常 sleep： reset pin 可能保持某个电平 irq pin 如果支持手势唤醒，需要保留输入和中断能力 irq pin 如果不支持唤醒，可能下拉避免浮空 I2C/SPI pin 可能切低功耗状态`

注意手势唤醒场景：

`如果 suspend 时把 irq pin 切成禁用或下拉， 触摸 IC 的 gesture irq 可能唤不醒系统。`

所以 sleep 状态不能随便配，要结合是否支持 gesture wakeup。

---

**Pinctrl 和 Suspend/Resume**

触摸屏常见流程：

`resume: select default pinctrl 上电 reset 初始化 IC enable irq suspend: disable irq 或进入 gesture mode 如果支持 gesture：保持 irq pin 可中断 如果不支持 gesture：select sleep pinctrl，降低功耗`

代码形态：

`static int ts_pinctrl_init(struct device *dev, struct ts_data *ts) { ts->pinctrl = devm_pinctrl_get(dev); if (IS_ERR(ts->pinctrl)) return PTR_ERR(ts->pinctrl); ts->pins_default = pinctrl_lookup_state(ts->pinctrl, "default"); if (IS_ERR(ts->pins_default)) return PTR_ERR(ts->pins_default); ts->pins_sleep = pinctrl_lookup_state(ts->pinctrl, "sleep"); if (IS_ERR(ts->pins_sleep)) return PTR_ERR(ts->pins_sleep); return pinctrl_select_state(ts->pinctrl, ts->pins_default); }`

实际驱动里要注意：有些项目 pinctrl 是可选资源，查不到可能只打印 warning，不一定直接 probe fail。

---

**Pin mux 典型问题**

如果 I2C/SPI pinmux 错了，表现可能是：

`I2C 读 chip id 失败 I2C NACK I2C timeout SPI 读出来全 0 或全 FF 逻辑分析仪看不到时钟或数据`

如果 reset pinmux 错了：

`reset 电平不变化 触摸 IC 不启动 I2C 地址无 ACK probe 失败`

如果 irq pinmux 错了：

`/proc/interrupts 计数不增加 getevent 没事件 触摸 IC 有数据但 AP 收不到中断 误中断很多`

---

**Pin config 典型问题**

上下拉配置错：

`irq 脚浮空，导致误触发 sleep 时漏电 唤醒不稳定 I2C 总线异常`

驱动强度配置不合适：

`边沿太慢 高速 SPI 通信不稳定 EMI 问题 功耗增加`

输入使能没开：

`GPIO 读值不对 中断不触发`

输出初始电平不对：

`设备上电时序异常 reset 释放过早或过晚`

---

**Pinctrl 常用调试方法**

看设备是否绑定 pinctrl 状态：

`cat /sys/kernel/debug/pinctrl/*/pinmux-pins cat /sys/kernel/debug/pinctrl/*/pinconf-pins cat /sys/kernel/debug/pinctrl/*/pinctrl-handles`

Android 上：

`adb shell cat /sys/kernel/debug/pinctrl/*/pinmux-pins adb shell cat /sys/kernel/debug/pinctrl/*/pinconf-pins adb shell cat /sys/kernel/debug/gpio adb shell cat /proc/interrupts`

如果 debugfs 没挂载：

`mount -t debugfs none /sys/kernel/debug`

常查内容：

`目标 pin 当前 mux 到哪个 function 是否被其他设备占用 pull-up / pull-down 是否符合预期 drive strength 是否符合预期 suspend 后状态是否变化`

---

**和设备树、驱动、硬件的关系**

Pinctrl 问题通常要三方一起看：

`原理图： pin 连接到哪里，是否需要上拉/下拉，电平有效性是什么 设备树： pinmux/function、bias、drive-strength、input-enable 是否正确 驱动： 是否选择了正确 pinctrl state，suspend/resume 是否切换状态`

例如触摸 IRQ：

`原理图：TP_INT 接 GPIO13，低电平中断，需要上拉 DTS：GPIO13 配成 GPIO input + pull-up 驱动：request_threaded_irq 使用 falling 或 low level`

三者有一个不一致，就会出问题。

---

**结合你这个 ILITEK 触摸驱动怎么讲**

你可以围绕这条线说：

`ILITEK 触摸 IC 需要 reset gpio、irq gpio、I2C pin。 pinctrl default 状态保证 reset/irq 管脚处于 GPIO 功能，I2C SDA/SCL 处于 I2C 功能，并配置上下拉和驱动能力。 probe 阶段先选择 default 状态，再上电 reset，然后通过 I2C 读取 chip id。 suspend 时如果不支持 gesture，可以切到 sleep 状态降低功耗； 如果支持 gesture wakeup，sleep 状态必须保留 irq pin 的输入和唤醒能力，不能把 irq 配成普通下拉失效状态。`

面试版可以这样回答：

> Pinctrl 子系统负责 SoC 管脚的复用和电气配置。比如触摸屏的 reset、irq、I2C/SPI 管脚，都需要通过 pinctrl 配成正确的 function、上下拉、输入输出和驱动强度。GPIO 子系统只能在 pin 已经被复用成 GPIO 后读写电平，而 pinctrl 决定这个 pin 是否是 GPIO、I2C、SPI 或其他功能。触摸驱动通常在设备树中配置 pinctrl-names = "default", "sleep"，probe 或 resume 时选择 default，suspend 时根据是否支持手势唤醒选择 sleep。调试时可以看 /sys/kernel/debug/pinctrl/*/pinmux-pins、pinconf-pins，结合 /sys/kernel/debug/gpio 和 /proc/interrupts 判断 pinmux、上下拉和中断是否正确。