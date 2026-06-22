
[[Linux 子系统汇总]]

**GPIO 子系统是什么**

GPIO 是 General Purpose Input/Output，通用输入输出管脚。  
Linux GPIO 子系统负责统一管理 SoC 或 GPIO 扩展芯片上的 GPIO 引脚，让驱动不用直接操作寄存器，而是通过标准接口控制引脚。

GPIO 常见用途：

`输入：中断脚、按键、状态检测脚 
`输出：reset、enable、power-on、chip-select、LED 控制 
`中断：触摸屏 IRQ、按键中断、Hall 中断`

在你看的触摸屏驱动里，GPIO 通常最重要的是：

`reset-gpio：控制触摸 IC 复位 
`irq-gpio：接收触摸 IC 中断`

---

**GPIO 子系统整体架构**

可以这样理解：

>`硬件 GPIO Controller 
	`↓ 
	`gpio_chip 驱动 
	`↓ 
	`GPIO core 
	`↓ 
	`gpiolib descriptor API 
	`↓ 
	`具体设备驱动：touch、camera、sensor、audio 等`

核心对象：

>`gpio_chip 表示一个 GPIO 控制器 
  `gpio_desc 表示一个具体 GPIO 引脚  
  `gpio_device GPIO core 内部设备对象 
  `irq_domain GPIO 转 IRQ 时使用`

驱动开发一般不直接操作 gpio_chip，而是使用 gpiod_* 接口拿到 struct gpio_desc *。

---

**老接口和新接口**

Linux GPIO 有两套常见接口。

老接口是基于 GPIO number：

`gpio_request(gpio, "reset"); 
`gpio_direction_output(gpio, 1); 
`gpio_set_value(gpio, 0); 
`gpio_free(gpio);`

新接口是 descriptor-based API：

`struct gpio_desc *reset_gpio; 
`reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH); gpiod_set_value(reset_gpio, 0);`

面试时建议明确说：

> 新内核推荐使用 descriptor-based GPIO API，也就是 gpiod_* 接口。它不依赖全局 GPIO number，更适合设备树和 ACPI 描述，也更安全。

---

**设备树中的 GPIO**

设备树里通常这样描述：

`ilitek@41 { 
`compatible = "ilitek,ili9881h"; 
`reg = <0x41>; 

==`reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; 
`irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>;

`interrupt-parent = <&pio>; 
`interrupts = <13 IRQ_TYPE_EDGE_FALLING>; 
`};`

注意命名规则：

驱动里：

>`devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);`

设备树属性名一般是：

>`reset-gpios`

驱动里：

>`devm_gpiod_get(dev, "irq", GPIOD_IN);`

设备树属性名一般是：

>`irq-gpios`

也就是说，devm_gpiod_get(dev, "reset", ...) 会去找 reset-gpios 或 reset-gpio。

---

**GPIO 输出：reset 脚**

触摸屏 reset 脚通常是输出 GPIO。

典型流程：

`reset_gpio = devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW); 
`if (IS_ERR(reset_gpio)) 
	`return PTR_ERR(reset_gpio); 
	
`gpiod_set_value(reset_gpio, 0); 
`msleep(5); 
`gpiod_set_value(reset_gpio, 1); 
`msleep(50);`

如果 reset 是低有效，设备树可以写：

`reset-gpios = <&pio 12 GPIO_ACTIVE_LOW>;`

然后驱动使用逻辑值：

`gpiod_set_value(reset_gpio, 1); `// active 
`gpiod_set_value(reset_gpio, 0); // inactive`

重点是：  
`gpiod_set_value() 使用的是逻辑电平，会考虑 GPIO_ACTIVE_LOW。  

如果想设置原始物理电平，可以用：

`gpiod_set_raw_value();`

面试里这个点很加分。

---

**GPIO 输入：IRQ 脚**

触摸屏中断脚通常是输入 GPIO。

驱动可以这样获取：

>`irq_gpio = devm_gpiod_get(dev, "irq", GPIOD_IN); 
 `if (IS_ERR(irq_gpio)) 
	`return PTR_ERR(irq_gpio);`

然后转成 IRQ number：

>`irq = gpiod_to_irq(irq_gpio); 
 `if (irq < 0) 
	`return irq;`

再申请中断：

>`ret = devm_request_threaded_irq(dev, irq, NULL, xxx_irq_thread, IRQF_ONESHOT |     IRQF_TRIGGER_FALLING, "xxx_touch", ts);`

完整链路：

>`Touch IC irq pin 
	`↓ 
  `SoC GPIO input 
	↓
  `GPIO controller 
	 ↓
  `gpiod_to_irq() 
	 ↓ 
  `Linux IRQ subsystem 
	↓ 
  `threaded irq handler 
	↓ 
  `I2C/SPI 读取触摸数据 
	↓
  `Input 子系统上报事件`

---

**GPIO 和 IRQ 的关系**

GPIO 是管脚，IRQ 是中断号。  
不是所有 GPIO 都一定能做 IRQ，但很多 SoC GPIO 都支持中断功能。

常见流程：

`GPIO pin -> gpio controller -> irq_domain -> Linux virq`

驱动中看到的 irq 通常是 Linux 虚拟中断号，不一定等于 GPIO number。

老接口：

`irq = gpio_to_irq(gpio_num);`

新接口：

`irq = gpiod_to_irq(gpio_desc);`

面试回答可以说：

> GPIO 子系统负责管脚输入输出，IRQ 子系统负责中断分发。GPIO 中断本质上是 GPIO controller 把某个 pin 的电平/边沿变化映射成 Linux IRQ，再由驱动 request_irq 或 request_threaded_irq 处理。

---

**GPIO 电平有效性：ACTIVE_HIGH / ACTIVE_LOW**

设备树经常写：

`reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>;`

这表示逻辑有效电平。

例如：

`reset-gpios = <&pio 12 GPIO_ACTIVE_LOW>;`

那么：

`gpiod_set_value(reset_gpio, 1);`

实际物理电平可能是低电平，因为 1 表示 active。

而：

`gpiod_set_value(reset_gpio, 0);`

实际物理电平可能是高电平，因为 0 表示 inactive。

所以新接口推荐用逻辑语义，不要在驱动里硬编码高低电平。

---

**GPIO API 常见分类**

申请 GPIO：

`devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW); devm_gpiod_get_optional(dev, "reset", GPIOD_OUT_LOW); devm_gpiod_get_index(dev, "reset", 0, GPIOD_OUT_LOW);`

设置方向：

`gpiod_direction_input(desc); gpiod_direction_output(desc, value);`

读写电平：

`gpiod_get_value(desc); gpiod_set_value(desc, value);`

可能睡眠版本：

`gpiod_get_value_cansleep(desc); gpiod_set_value_cansleep(desc, value);`

转 IRQ：

`gpiod_to_irq(desc);`

释放资源：

`gpiod_put(desc);`

如果使用 devm_gpiod_get()，通常不需要手动 gpiod_put()，设备释放时自动清理。

---

**什么时候用 _cansleep**

这是面试高频点。

有些 GPIO 控制器访问很快，比如 SoC 内部 MMIO GPIO，读写不会睡眠。  
有些 GPIO 来自 I2C/SPI 扩展芯片，例如 GPIO expander，读写 GPIO 需要走 I2C/SPI，可能睡眠。

所以 Linux 提供：

`gpiod_set_value() gpiod_set_value_cansleep()`

如果 GPIO 可能睡眠，要用 _cansleep 版本，且不能在硬中断上下文使用。

判断方式：

`gpiod_cansleep(desc)`

面试回答：

> 如果 GPIO controller 位于 I2C/SPI 等慢速总线上，访问 GPIO 可能睡眠，此时必须使用 gpiod_get_value_cansleep() 或 gpiod_set_value_cansleep()。硬中断里不能调用可能睡眠的 GPIO API。

---

**pinctrl 和 GPIO 的区别**

很多人会混淆 GPIO 和 pinctrl。

可以这样区分：

`pinctrl：决定管脚复用成什么功能，以及上下拉、驱动强度、电气状态 GPIO：当这个 pin 被复用成 GPIO 后，控制它输入/输出和值`

例如同一个 pin 可以是：

`GPIO I2C_SDA SPI_MOSI UART_TX PWM`

pinctrl 负责选择它当前是 GPIO 还是某个复用功能。  
GPIO 子系统负责在 GPIO 模式下读写它。

触摸屏里常见：

`pinctrl-names = "default", "sleep"; pinctrl-0 = <&tp_default>; pinctrl-1 = <&tp_sleep>;`

驱动 suspend/resume 时可能切换 pinctrl 状态：

`pinctrl_select_state(ts->pinctrl, ts->pins_sleep); pinctrl_select_state(ts->pinctrl, ts->pins_default);`

---

**GPIO hog**

设备树中还有一种叫 GPIO hog 的机制，用于在 GPIO controller 初始化时自动把某些 GPIO 设置成固定状态，不需要具体驱动控制。

例如：

`wifi-en-hog { gpio-hog; gpios = <10 GPIO_ACTIVE_HIGH>; output-high; line-name = "wifi-enable"; };`

面试知道即可，不是触摸主线重点。

---

**GPIO consumer 名称**

新 GPIO API 中的 "reset"、"irq" 叫 consumer name：

`devm_gpiod_get(dev, "reset", GPIOD_OUT_HIGH);`

对应设备树：

`reset-gpios = <...>;`

如果是数组：

`reset-gpios = <&pio 1 GPIO_ACTIVE_HIGH>, <&pio 2 GPIO_ACTIVE_HIGH>;`

可以用：

`devm_gpiod_get_index(dev, "reset", 1, GPIOD_OUT_LOW);`

---

**调试 GPIO**

常用调试命令：

`cat /sys/kernel/debug/gpio 
`cat /proc/interrupts 
`cat /proc/device-tree/.../reset-gpios 
`cat /proc/device-tree/.../irq-gpios`

新系统也可以用 libgpiod 工具：

>`gpioinfo 
  `gpioget 
  `gpiochip0 12 
  `gpioset gpiochip0 12=1`

Android/嵌入式平台经常：

`adb shell 
`cat /sys/kernel/debug/gpio 
`adb shell 
`cat /proc/interrupts 
`adb shell dmesg | grep -i gpio`

触摸屏排查时重点看：

`reset gpio 是否申请成功 
`reset 电平时序是否正确 
`irq gpio 是否配置成输入 
`irq 触发类型是否正确 
`/proc/interrupts 计数是否增长 
`pinctrl default/sleep 状态是否正确 
`GPIO_ACTIVE_LOW/HIGH 是否写反`

---

**常见问题**

**1. reset 无效**

可能原因：

`设备树 GPIO 编号错 GPIO_ACTIVE_LOW/HIGH 写反 pinctrl 没把 pin 配成 GPIO 电源没开 reset 时序延时不够 驱动里用 raw value 和逻辑 value 混乱`

**2. 中断不触发**

可能原因：

`irq-gpio 配错 interrupt-parent 配错 触发类型错，falling/rising/level 写错 pinctrl 没配置输入/上拉 触摸 IC 没上电或没出 reset request_irq 没成功 中断被 disable`

**3. GPIO 读写报错**

可能原因：

`GPIO 被别的驱动占用 设备树属性名和 devm_gpiod_get 名称不匹配 GPIO controller 驱动没加载 权限或 debugfs 未挂载`

---

**结合触摸屏驱动的标准回答**

面试可以这样说：

> GPIO 子系统在触摸屏驱动里主要用于 reset 和 irq。probe 阶段驱动会从设备树获取 reset-gpios 和 irq-gpios。reset gpio 配成输出，用来控制触摸 IC 的硬件复位时序；irq gpio 配成输入，并通过 gpiod_to_irq() 或 gpio_to_irq() 转成 Linux IRQ，然后调用 request_threaded_irq() 注册中断处理函数。触摸 IC 有数据时拉动 irq 脚，GPIO controller 把边沿或电平变化映射成 IRQ，驱动在线程化中断里通过 I2C/SPI 读取坐标，再上报到 Input 子系统。

也可以再补一句：

> 新内核推荐使用 gpiod_* descriptor API，因为它基于设备树 consumer 名称，不依赖全局 GPIO number，并且能正确处理 GPIO_ACTIVE_LOW 这种逻辑电平描述。