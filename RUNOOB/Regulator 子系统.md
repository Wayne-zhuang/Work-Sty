
[[Linux 子系统汇总]]

**regulator 子系统是什么**

Regulator 子系统是 Linux 内核里统一管理电源轨的框架。  
它负责控制 LDO、BUCK、DCDC、PMIC 输出等电源资源。

在驱动里，regulator 通常对应硬件上的某一路电源，例如：

`vdd 芯片核心电源 iovdd IO 电源 avdd 模拟电源 dvdd 数字电源 vcc 通用电源名`

触摸屏里常见：

`VDD / AVDD：给触摸 IC 核心或模拟部分供电 IOVDD：给 I2C/SPI/GPIO IO 域供电`

一句话：

> Regulator 子系统负责让驱动以统一方式打开、关闭、设置电压和管理电源依赖，而不是直接操作 PMIC 寄存器。

---

**为什么需要 Regulator**

不同平台电源来源不同：

`有的平台由 PMIC LDO 供电 有的平台由 GPIO enable 控制 有的平台一直上电，不能关 有的平台多个设备共用一条电源`

如果每个驱动都直接操作 PMIC，会非常混乱。  
Regulator 子系统提供统一抽象：

`consumer driver：触摸屏、camera、sensor 等用电设备 regulator provider：PMIC、固定电源、GPIO regulator 等供电设备 regulator core：负责引用计数、约束、电压范围、enable/disable`

---

**Regulator 架构**

可以这样理解：

`PMIC / fixed regulator / gpio regulator ↓ regulator provider driver ↓ Regulator core ↓ consumer API ↓ 具体设备驱动，比如 touch driver`

核心对象：

`struct regulator_dev 表示一个实际 regulator provider struct regulator consumer 拿到的电源句柄 regulator_ops provider 实现的操作，比如 enable/set_voltage regulation_constraints 电压、电流、开关限制`

触摸驱动一般只关心 struct regulator *。

---

**设备树中的 Regulator**

触摸 IC 节点里通常引用电源：

`touchscreen@41 { compatible = "ilitek,ili9881h"; reg = <0x41>; vdd-supply = <&pmic_ldo5>; iovdd-supply = <&pmic_ldo6>; reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>; };`

驱动里对应：

`vdd = devm_regulator_get(dev, "vdd"); iovdd = devm_regulator_get(dev, "iovdd");`

命名规则：

`驱动 devm_regulator_get(dev, "vdd") 设备树属性是 vdd-supply 驱动 devm_regulator_get(dev, "iovdd") 设备树属性是 iovdd-supply`

这点面试和调试都很重要。

---

**固定电源 fixed-regulator**

有些电源不是 PMIC 动态控制的，而是固定存在，设备树可以写成：

`tp_vdd: regulator-tp-vdd { compatible = "regulator-fixed"; regulator-name = "tp_vdd"; regulator-min-microvolt = <3300000>; regulator-max-microvolt = <3300000>; gpio = <&pio 20 GPIO_ACTIVE_HIGH>; enable-active-high; startup-delay-us = <5000>; };`

然后触摸节点引用：

`vdd-supply = <&tp_vdd>;`

这样触摸驱动仍然只调用：

`regulator_enable(vdd);`

底层可能实际是拉高一个 GPIO。

---

**常用 Consumer API**

获取 regulator：

`struct regulator *vdd; vdd = devm_regulator_get(dev, "vdd"); if (IS_ERR(vdd)) return PTR_ERR(vdd);`

可选电源：

`vdd = devm_regulator_get_optional(dev, "vdd"); if (IS_ERR(vdd)) { if (PTR_ERR(vdd) == -ENODEV) vdd = NULL; else return PTR_ERR(vdd); }`

设置电压：

`ret = regulator_set_voltage(vdd, 2800000, 3300000);`

打开电源：

`ret = regulator_enable(vdd);`

关闭电源：

`regulator_disable(vdd);`

查询状态：

`regulator_is_enabled(vdd);`

批量接口：

`struct regulator_bulk_data supplies[] = { { .supply = "vdd" }, { .supply = "iovdd" }, }; ret = devm_regulator_bulk_get(dev, ARRAY_SIZE(supplies), supplies); ret = regulator_bulk_enable(ARRAY_SIZE(supplies), supplies); regulator_bulk_disable(ARRAY_SIZE(supplies), supplies);`

触摸屏有多路电源时，bulk 接口更干净。

---

**上电时序**

触摸 IC 对上电顺序通常比较敏感。典型顺序：

`1. 选择 pinctrl default 2. enable iovdd 3. enable vdd 4. 等待电源稳定 5. 拉 reset 到 active 6. 延时 7. 释放 reset 8. 等待 IC boot 9. 通过 I2C/SPI 读 chip id`

不同 IC 可能要求不同，例如：

`先 VDD 后 IOVDD IOVDD 不能早于 VDD 太久 reset 必须在电源稳定后保持低电平一段时间 释放 reset 后要等 50ms/100ms 才能通信`

实际要以 datasheet 或厂商移植文档为准。

---

**下电时序**

下电一般反过来：

`1. disable irq 2. 拉 reset active，避免 IC 异常输出 3. disable vdd 4. disable iovdd 5. 选择 pinctrl sleep`

注意：

`如果 IO 电源关了，但主控 GPIO 还输出高电平，可能通过 IO 反灌电。`

所以 suspend/power off 时要注意 GPIO 状态和 pinctrl sleep 状态。

---

**regulator_enable/disable 的引用计数**

Regulator core 内部会维护 enable count。

例如两个设备共用同一电源：

`device A regulator_enable device B regulator_enable device A regulator_disable`

这时电源不会立刻关闭，因为 B 还在使用。  
只有 enable count 归零时，provider 才真正关电。

所以面试可以说：

> Regulator 子系统会处理共享电源的引用计数和约束，consumer driver 不应该直接操作 PMIC 寄存器。

---

**always-on 和 boot-on**

设备树里 regulator 常见属性：

`regulator-always-on; regulator-boot-on;`

区别：

`regulator-always-on： 这路电源不能关闭，即使没人使用也保持开启。 regulator-boot-on： bootloader 已经打开，内核启动时认为它可能是开启状态； 后续如果没有 consumer 使用，仍可能被关闭。`

如果某路触摸电源被错误关闭，可能导致触摸 probe 或 resume 失败。  
调试时要看 regulator 是否被约束成 always-on，或者是否被 late init 关闭了 unused regulator。

---

**电压约束**

设备树中 provider 一般会写：

`regulator-min-microvolt = <1800000>; regulator-max-microvolt = <1800000>;`

驱动也可能设置：

`regulator_set_voltage(iovdd, 1800000, 1800000); regulator_set_voltage(vdd, 3300000, 3300000);`

如果驱动要求的电压超出设备树约束，regulator_set_voltage() 会失败。

常见错误：

`驱动要 3.3V，但 DTS regulator 只允许 1.8V 驱动没设置电压，provider 默认电压不对 多个 consumer 对同一电源要求冲突`

---

**可选电源和 dummy regulator**

如果设备树没写 vdd-supply，驱动调用：

`devm_regulator_get(dev, "vdd");`

可能出现：

`supply vdd not found, using dummy regulator`

有些内核配置会给 dummy regulator。  
这不一定马上报错，但实际硬件如果真的需要控制电源，可能导致上电失败。

面试和调试时可以说：

> 看到 dummy regulator 不能简单认为没问题，要结合原理图确认这路电源是固定常开，还是设备树漏配了 supply。

---

**Regulator 和 Runtime PM / System PM**

Regulator 常和电源管理配合：

`probe：获取 regulator，必要时上电初始化 suspend：如果不需要唤醒，关闭电源或进入低功耗 resume：重新上电、reset、初始化 remove：关闭电源释放资源`

触摸屏场景：

`不支持手势唤醒： suspend 可以 disable regulator，降低功耗 支持手势唤醒： suspend 不能完全断电，要保持触摸 IC 低功耗运行 可能只写命令进入 gesture mode irq 仍保持 wakeup`

所以不是所有 suspend 都应该 regulator_disable()。

---

**调试 Regulator**

常用 debugfs：

`cat /sys/kernel/debug/regulator/regulator_summary`

Android：

`adb shell cat /sys/kernel/debug/regulator/regulator_summary`

可以看：

`regulator 名称 是否 enabled use_count open_count 电压 consumer 列表 constraints`

常用 log：

`dmesg | grep -i regulator dmesg | grep -i supply dmesg | grep -i ilitek`

触摸问题排查重点：

`vdd-supply / iovdd-supply 是否匹配驱动名称 regulator_enable 是否成功 电压是否正确 上电后延时是否足够 resume 后是否重新上电/reset suspend 时是否误关 gesture 所需电源 是否出现 dummy regulator 是否有 unused regulator 被内核关闭`

---

**常见问题**

**1. probe 读 chip id 失败**

可能原因：

`vdd/iovdd 没开 电压不对 reset 在电源稳定前释放 上电延时不够 DTS supply 名称和驱动 get 名称不匹配 regulator 被配置成 disabled 或约束错误`

**2. suspend 后无法唤醒**

可能原因：

`支持 gesture 但 suspend 里 disable regulator irq 电源域断了 pinctrl sleep 把 irq 配坏 enable_irq_wake 没调用 触摸 IC 没进入 gesture mode`

**3. resume 后 I2C 通信失败**

可能原因：

`regulator_enable 后没有等待稳定 reset 时序不完整 IOVDD/VDD 顺序错误 IC 仍在 sleep/gesture 模式 I2C pinctrl 没恢复 default`

**4. 偶发通信失败**

可能原因：

`电源纹波大 电压设置不对 enable 后延时不足 reset 时序临界 SPI/I2C 驱动强度或 pull 配置不合理`

---

**结合 ILITEK 触摸驱动怎么讲**

你可以这样组织项目经验：

`ILITEK 触摸屏需要 VDD/IOVDD 供电。 驱动 probe 阶段会通过 regulator_get 或 regulator_bulk_get 获取电源， 再 regulator_enable 打开电源，配合 reset gpio 做硬件复位。 电源稳定后，通过 I2C 读取 chip id 或 firmware version，确认 IC 在线。 suspend 时，如果不支持手势唤醒，可以关闭 regulator 降低功耗； 如果支持 gesture wakeup，不能直接断电，而是让 IC 进入 gesture mode， 保留必要电源和 irq wake 能力。 resume 时重新打开电源、切 pinctrl default、reset IC，再恢复正常报点。`

面试版回答：

> Regulator 子系统负责统一管理设备电源，比如 PMIC LDO、BUCK 或 fixed regulator。触摸驱动作为 consumer，通过 devm_regulator_get(dev, "vdd") 获取 vdd-supply，通过 regulator_enable() 上电，通过 regulator_disable() 下电。Regulator core 会处理共享电源的引用计数、电压约束和 provider 操作。触摸屏驱动中要特别注意 VDD/IOVDD 的上电顺序、reset 时序、上电后等待时间，以及 suspend 时是否支持手势唤醒。如果支持 gesture，通常不能关闭关键 regulator，否则触摸 IC 无法产生唤醒中断。