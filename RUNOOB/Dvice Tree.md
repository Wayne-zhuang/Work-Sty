
[[Linux 子系统汇总]][[I2C&SPI子系统]][[Input 子系统]][[Regulator 子系统]]

**Device Tree 是什么**

Device Tree，简称 DT 或 DTS，是 Linux 内核用来描述硬件资源的数据结构。  
它把“板级硬件信息”从驱动代码里分离出来。

简单说：

`驱动代码负责逻辑： 怎么上电、怎么 reset、怎么读 I2C、怎么上报 input Device Tree 负责描述硬件： 设备挂在哪条总线 I2C 地址是多少 用哪个 GPIO 用哪路电源 pinctrl 怎么配 IRQ 是哪个脚 屏幕分辨率/坐标范围是多少`

这样同一个驱动可以适配不同板子，只需要改 DTS，不需要改 C 代码。

---

**为什么需要 Device Tree**

如果没有 Device Tree，驱动里可能要硬编码：

`#define TP_I2C_ADDR 0x41 #define TP_RESET_GPIO 12 #define TP_IRQ_GPIO 13 #define TP_VDD "ldo5"`

这会导致：

`换一块板子就要改驱动 驱动和硬件绑定太死 多个项目难维护 内核无法统一管理资源`

有了 Device Tree 后，驱动通过标准 API 获取资源：

`devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW); devm_regulator_get(dev, "vdd"); devm_pinctrl_get(dev); client->addr; client->irq;`

硬件差异放在 DTS 中。

---

**DTS / DTSI / DTB**

常见文件类型：

`.dts 板级设备树文件，一般描述具体 board .dtsi 公共 include 文件，一般描述 SoC 或平台公共硬件 .dtb 编译后的二进制设备树，bootloader 传给 kernel .dtbo Device Tree Overlay，常用于 Android 动态叠加`

关系：

`xxx.dts + xxx.dtsi ↓ dtc 编译 xxx.dtb ↓ bootloader 加载 kernel 启动解析`

Android 项目里还经常有：

`dtbo.img vendor_boot.img`

不同平台组织方式不一样。

---

**Device Tree 基本语法**

一个节点示例：

`touchscreen@41 { compatible = "ilitek,ili9881h"; reg = <0x41>; status = "okay"; reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>; vdd-supply = <&tp_vdd>; iovdd-supply = <&tp_iovdd>; pinctrl-names = "default", "sleep"; pinctrl-0 = <&tp_default>; pinctrl-1 = <&tp_sleep>; };`

常见元素：

`touchscreen@41 节点名，@ 后通常是地址 compatible 用于匹配驱动 reg 设备地址或寄存器范围 status 是否启用 xxx-gpios GPIO 资源 xxx-supply regulator 资源 pinctrl-names pinctrl 状态名 pinctrl-0/1 pinctrl 状态引用`

---

**compatible：驱动匹配关键**

compatible 是设备和驱动匹配的核心。

DTS：

`compatible = "ilitek,ili9881h";`

驱动：

`static const struct of_device_id ilitek_match_table[] = { { .compatible = "ilitek,ili9881h" }, { } }; MODULE_DEVICE_TABLE(of, ilitek_match_table);`

驱动结构：

`static struct i2c_driver ilitek_i2c_driver = { .driver = { .name = "ilitek", .of_match_table = ilitek_match_table, }, .probe = ilitek_i2c_probe, };`

匹配流程：

`kernel 解析 DT ↓ 在 I2C 总线下创建 i2c_client ↓ I2C core 用 compatible 匹配 i2c_driver ↓ 匹配成功后调用 probe`

如果 compatible 写错，驱动 probe 不会进。

---

**reg：地址信息**

在 I2C 设备里：

`touchscreen@41 { reg = <0x41>; };`

reg = <0x41> 表示 I2C 7-bit 地址是 0x41。

在 SPI 设备里：

`touchscreen@0 { reg = <0>; };`

reg = <0> 通常表示 chip select 0。

在 memory-mapped 外设里：

`uart@11002000 { reg = <0x11002000 0x1000>; };`

表示寄存器基地址和长度。

---

**status：启用或禁用设备**

常见：

`status = "okay"; status = "disabled";`

如果节点是：

`status = "disabled";`

通常设备不会被创建，驱动也不会 probe。

面试可以说：

> 很多外设在 SoC dtsi 里默认 disabled，板级 dts 根据实际硬件把它改成 okay。

---

**GPIO 在 Device Tree 中的写法**

例子：

`reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>;`

含义：

`&pio GPIO controller phandle 12 / 13 GPIO 编号 GPIO_ACTIVE_HIGH 逻辑有效高 GPIO_ACTIVE_LOW 逻辑有效低`

驱动获取：

`reset = devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW); irq_gpio = devm_gpiod_get(dev, "irq", GPIOD_IN);`

命名规则：

`devm_gpiod_get(dev, "reset") -> reset-gpios devm_gpiod_get(dev, "irq") -> irq-gpios`

---

**Interrupts 在 Device Tree 中的写法**

触摸屏一般会有中断：

`interrupt-parent = <&pio>; interrupts = <13 IRQ_TYPE_EDGE_FALLING>;`

或者有些平台写：

`interrupts-extended = <&pio 13 IRQ_TYPE_EDGE_FALLING>;`

含义：

`interrupt-parent 中断控制器 13 中断源编号，可能是 GPIO 编号或 controller 内部编号 IRQ_TYPE_EDGE_FALLING 下降沿触发`

驱动可以直接用：

`client->irq`

或者：

`irq = gpiod_to_irq(irq_gpio);`

再申请：

`devm_request_threaded_irq(dev, irq, NULL, irq_thread, IRQF_ONESHOT, "ilitek", ts);`

注意：

`irq-gpios 描述 GPIO 资源 interrupts 描述中断资源 有些驱动只用 irq-gpios + gpiod_to_irq 有些驱动直接用 interrupts / client->irq 有些两个都写`

---

**Regulator 在 Device Tree 中的写法**

触摸节点引用电源：

`vdd-supply = <&tp_vdd>; iovdd-supply = <&tp_iovdd>;`

驱动：

`vdd = devm_regulator_get(dev, "vdd"); iovdd = devm_regulator_get(dev, "iovdd");`

provider 可能是 PMIC LDO，也可能是 fixed regulator：

`tp_vdd: regulator-tp-vdd { compatible = "regulator-fixed"; regulator-name = "tp_vdd"; regulator-min-microvolt = <3300000>; regulator-max-microvolt = <3300000>; startup-delay-us = <5000>; };`

命名规则：

`devm_regulator_get(dev, "vdd") -> vdd-supply`

---

**Pinctrl 在 Device Tree 中的写法**

设备节点引用状态：

`pinctrl-names = "default", "sleep"; pinctrl-0 = <&tp_pins_default>; pinctrl-1 = <&tp_pins_sleep>;`

驱动：

`pinctrl = devm_pinctrl_get(dev); pins_default = pinctrl_lookup_state(pinctrl, "default"); pins_sleep = pinctrl_lookup_state(pinctrl, "sleep");`

状态定义一般在 pin controller 节点下：

`tp_pins_default: tp-default { pins = "gpio12", "gpio13"; function = "gpio"; bias-pull-up; };`

不同 SoC 的 pinctrl binding 差异很大，MTK/QCOM/Rockchip 写法都不完全一样。

---

**#address-cells 和 #size-cells**

这个是 DTS 面试高频点。

例如 I2C bus：

`&i2c1 { #address-cells = <1>; #size-cells = <0>; touchscreen@41 { reg = <0x41>; }; };`

含义：

`#address-cells = <1> 子节点 reg 地址占 1 个 cell #size-cells = <0> 子节点 reg 不包含 size`

所以 I2C 设备的 reg 只有地址：

`reg = <0x41>;`

memory-mapped bus 常见：

`#address-cells = <1>; #size-cells = <1>; uart@11002000 { reg = <0x11002000 0x1000>; };`

这里 reg 包含地址和长度。

---

**phandle 是什么**

DTS 中 &xxx 是 phandle 引用。

例如：

`vdd-supply = <&tp_vdd>; pinctrl-0 = <&tp_default>; reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>;`

含义：

`&tp_vdd 引用 tp_vdd 这个 regulator 节点 &tp_default 引用 tp_default 这个 pinctrl 状态 &pio 引用 GPIO controller 节点`

标签定义：

`tp_vdd: regulator-tp-vdd { ... };`

tp_vdd: 就是 label，可以被 &tp_vdd 引用。

---

**驱动如何读取 Device Tree 属性**

常见 API：

`struct device_node *np = dev->of_node;`

读整数：

`of_property_read_u32(np, "touchscreen-size-x", &x_max);`

读布尔：

`of_property_read_bool(np, "ilitek,gesture-enabled");`

读字符串：

`of_property_read_string(np, "firmware-name", &fw_name);`

读数组：

`of_property_read_u32_array(np, "panel-size", data, 2);`

获取 GPIO：

`devm_gpiod_get(dev, "reset", GPIOD_OUT_LOW);`

获取 regulator：

`devm_regulator_get(dev, "vdd");`

获取 IRQ：

`irq = irq_of_parse_and_map(np, 0);`

不过新驱动更推荐用子系统封装 API，而不是自己解析所有 phandle。

---

**Device Tree Binding**

binding 是某类设备的 DTS 写法规范。  
新内核里通常是 YAML 文件：

`Documentation/devicetree/bindings/`

它规定：

`compatible 应该叫什么 必须有哪些属性 可选有哪些属性 属性类型是什么 示例怎么写`

例如触摸屏 binding 可能要求：

`compatible reg interrupts reset-gpios vcc-supply touchscreen-size-x touchscreen-size-y`

面试可以说：

> DTS 不是随便写属性名，应该符合对应驱动或通用 subsystem 的 binding。否则驱动可能读不到，dtbs_check 也会报错。

---

**触摸屏常见 DTS 属性**

常见属性包括：

`touchscreen@41 { compatible = "ilitek,ili9881h"; reg = <0x41>; status = "okay"; interrupt-parent = <&pio>; interrupts = <13 IRQ_TYPE_EDGE_FALLING>; reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; vdd-supply = <&tp_vdd>; iovdd-supply = <&tp_iovdd>; pinctrl-names = "default", "sleep"; pinctrl-0 = <&tp_default>; pinctrl-1 = <&tp_sleep>; touchscreen-size-x = <720>; touchscreen-size-y = <1600>; touchscreen-inverted-x; touchscreen-swapped-x-y; firmware-name = "ilitek/ili9881h_fw.bin"; ilitek,gesture-enabled; };`

通用 touchscreen 属性常见：

`touchscreen-size-x touchscreen-size-y touchscreen-inverted-x touchscreen-inverted-y touchscreen-swapped-x-y`

具体驱动也可能定义私有属性：

`ilitek,gesture-enabled ilitek,tp-reset-delay-ms ilitek,fw-name`

---

**Device Tree 和触摸驱动 probe 的关系**

触摸驱动 probe 里一般会做：

`1. 拿 dev->of_node 2. 读取坐标范围、panel 信息、feature flag 3. 获取 regulator：vdd/iovdd 4. 获取 pinctrl：default/sleep 5. 获取 reset-gpio、irq-gpio 6. 获取 irq number 7. 上电 reset 8. I2C/SPI 读 chip id 9. 注册 input device 10. request irq`

所以 DTS 配错，经常导致 probe 失败或功能异常。

---

**调试 Device Tree**

运行时查看设备树：

`ls /proc/device-tree cat /proc/device-tree/.../compatible cat /proc/device-tree/.../status hexdump -C /proc/device-tree/.../reg`

Android 上：

`adb shell ls /proc/device-tree adb shell cat /proc/device-tree/model adb shell find /proc/device-tree -name "*touch*"`

查看驱动是否 probe：

`dmesg | grep -i ilitek dmesg | grep -i touchscreen dmesg | grep -i "probe"`

查看 I2C 设备：

`ls /sys/bus/i2c/devices/ cat /sys/bus/i2c/devices/1-0041/name`

查看 input：

`cat /proc/bus/input/devices getevent -lp`

查看 GPIO / pinctrl / regulator：

`cat /sys/kernel/debug/gpio cat /sys/kernel/debug/pinctrl/*/pinmux-pins cat /sys/kernel/debug/regulator/regulator_summary cat /proc/interrupts`

---

**常见 DTS 配错问题**

**1. compatible 错**

表现：

`驱动 probe 不进 没有 /dev/input/eventX dmesg 没有触摸驱动初始化 log`

**2. reg 地址错**

表现：

`probe 进了，但读 chip id 失败 I2C NACK i2cdetect 看不到对应地址`

**3. reset-gpios 错**

表现：

`reset 没有波形 触摸 IC 不启动 I2C 无 ACK`

**4. irq 配错**

表现：

`probe 成功，但触摸无事件 /proc/interrupts 计数不增加 或者中断风暴`

**5. pinctrl 配错**

表现：

`I2C/SPI 通信失败 GPIO 不变化 IRQ 不触发 sleep/resume 后异常`

**6. regulator supply 名称错**

表现：

`supply not found using dummy regulator 电源没开 读 chip id 失败`

**7. 坐标属性错**

表现：

`触摸偏移 坐标比例不对 X/Y 反了 边缘触摸不到`

---

**结合你这个 ILITEK 项目怎么说**

如果面试官问你 Device Tree，你可以结合触摸屏说：

> Device Tree 在触摸驱动中主要描述板级硬件资源。以 ILITEK 触摸屏为例，它会挂在某条 I2C 总线下，DTS 中通过 compatible 匹配驱动，通过 reg 描述 I2C 地址，通过 reset-gpios 和 irq-gpios 描述复位脚和中断脚，通过 vdd-supply、iovdd-supply 描述电源，通过 pinctrl-0/1 描述 default 和 sleep 管脚状态，还可能通过 touchscreen-size-x/y 描述坐标范围。驱动 probe 时从 dev->of_node 或各子系统 API 获取这些资源，然后完成上电、reset、读 chip id、注册 input、申请 irq。这样同一个驱动可以适配不同硬件板，只需要修改 DTS。