
[[Linux 子系统汇总]] [[Touch]] [[I2C]][[SPI]]

**I2C/SPI 子系统在触摸驱动里的作用**

触摸屏驱动里，I2C 或 SPI 负责主控 SoC 和触摸 IC 之间的数据通信。

典型链路是：

`手指触摸屏幕 ↓ 触摸 IC 采样、计算坐标 ↓ 触摸 IC 拉 IRQ GPIO ↓ 主控进入触摸中断线程 ↓ 驱动通过 I2C/SPI 读取触摸 IC 数据 ↓ 解析 x/y/id/pressure ↓ 通过 Input 子系统上报`

所以 GPIO/IRQ 只负责“通知有数据”，真正的数据读取靠 I2C 或 SPI。

---

**I2C 和 SPI 的区别**

`I2C： 两根线：SCL、SDA 半双工 有设备地址 速度相对较低 接线少，常用于触摸、sensor、PMIC、EEPROM SPI： 常见四根线：SCLK、MOSI、MISO、CS 全双工 通过片选 CS 选择设备 速度较高 常用于屏、flash、指纹、部分高报点率触摸 IC`

触摸屏上两者都常见。  
你现在看的文件名里有 ilitek_v3_i2c.c，说明这个项目大概率是 I2C 触摸通信主线。

---

**I2C 子系统架构**

I2C 可以从三层理解：

`I2C controller / adapter ↓ I2C core ↓ I2C client driver ↓ 触摸 IC`

核心对象：

`struct i2c_adapter 表示一个 I2C 控制器，比如 i2c-0、i2c-1 struct i2c_client 表示挂在总线上的一个 I2C 设备 struct i2c_driver 表示一个 I2C 设备驱动 struct i2c_msg 表示一次 I2C 传输消息`

触摸驱动通常注册一个 i2c_driver：

`static struct i2c_driver ilitek_i2c_driver = { .driver = { .name = "ilitek", .of_match_table = ilitek_of_match, }, .probe = ilitek_i2c_probe, .remove = ilitek_i2c_remove, .id_table = ilitek_i2c_id, }; module_i2c_driver(ilitek_i2c_driver);`

设备树中对应一个 I2C 设备节点：

`&i2c1 { status = "okay"; touchscreen@41 { compatible = "ilitek,ili9881h"; reg = <0x41>; reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>; interrupt-parent = <&pio>; interrupts = <13 IRQ_TYPE_EDGE_FALLING>; }; };`

这里：

`&i2c1 对应 i2c_adapter touchscreen@41 对应 i2c_client reg = <0x41> 是 7-bit I2C 地址 compatible 用于匹配 i2c_driver`

---

**I2C probe 是怎么来的**

启动时流程大致是：

`I2C controller 驱动注册 adapter ↓ 内核解析设备树 i2c 节点 ↓ 为 touchscreen@41 创建 i2c_client ↓ i2c core 用 compatible 匹配 i2c_driver ↓ 匹配成功后调用 driver.probe(client)`

也就是说，触摸驱动的 probe 不是自己主动调用的，而是 I2C core 在设备和驱动匹配后调用的。

面试可以答：

> I2C 设备由设备树描述，I2C controller 注册 adapter 后，I2C core 根据子节点创建 i2c_client，再根据 compatible 或 id_table 匹配 i2c_driver，匹配成功后调用 probe。

---

**I2C 常见传输接口**

简单读写：

`i2c_master_send(client, buf, len); i2c_master_recv(client, buf, len);`

组合传输：

`i2c_transfer(client->adapter, msgs, num);`

SMBus 接口：

`i2c_smbus_read_byte_data(client, reg); i2c_smbus_write_byte_data(client, reg, val);`

触摸屏驱动常用 i2c_transfer()，因为很多触摸 IC 协议不是标准 SMBus。

例如写命令：

`ret = i2c_master_send(client, txbuf, txlen); if (ret != txlen) return -EIO;`

例如先写寄存器地址，再读数据：

`struct i2c_msg msgs[2]; msgs[0].addr = client->addr; msgs[0].flags = 0; msgs[0].buf = wbuf; msgs[0].len = wlen; msgs[1].addr = client->addr; msgs[1].flags = I2C_M_RD; msgs[1].buf = rbuf; msgs[1].len = rlen; ret = i2c_transfer(client->adapter, msgs, 2); if (ret != 2) return -EIO;`

---

**I2C 通信上下文**

I2C 传输可能睡眠，所以不能放在硬中断里执行。

错误示例：

`static irqreturn_t xxx_irq_handler(int irq, void *dev_id) { i2c_master_recv(client, buf, len); // 不应该在硬中断里做 return IRQ_HANDLED; }`

正确做法通常是 threaded irq：

`devm_request_threaded_irq(dev, irq, NULL, xxx_irq_thread, IRQF_ONESHOT | IRQF_TRIGGER_FALLING, "xxx_ts", ts);`

在线程化中断里读 I2C：

`static irqreturn_t xxx_irq_thread(int irq, void *dev_id) { struct xxx_ts *ts = dev_id; xxx_i2c_read(ts, buf, len); xxx_report_touch(ts, buf); return IRQ_HANDLED; }`

面试可以强调：

> I2C/SPI 传输可能睡眠，尤其 I2C 一定不能在硬中断上下文里做。触摸驱动通常使用 threaded irq 或 workqueue 来完成通信和上报。

---

**I2C 错误处理**

I2C 常见错误：

`-ENXIO 没有设备 ACK，地址不对或设备没响应 -EREMOTEIO 常见于 NACK -ETIMEDOUT 总线超时 -EIO 通用 IO 错误 -EBUSY 总线忙`

触摸屏 I2C 失败常见原因：

`触摸 IC 没上电 reset 时序不对 I2C 地址错 pinctrl 没把 SDA/SCL 配成 I2C 功能 上拉电阻或电压域问题 设备处于 sleep/bootloader 模式 中断来了但 IC 数据还没准备好`

驱动里通常会做 retry：

`for (retry = 0; retry < 3; retry++) { ret = i2c_transfer(...); if (ret == expected) return 0; msleep(20); } return -EIO;`

---

**I2C 设备树关键点**

I2C 控制器节点：

`&i2c1 { clock-frequency = <400000>; pinctrl-names = "default"; pinctrl-0 = <&i2c1_pins>; status = "okay"; };`

触摸 IC 子节点：

`touchscreen@41 { compatible = "ilitek,ili9881h"; reg = <0x41>; status = "okay"; };`

常见检查点：

`i2c controller status 是否 okay clock-frequency 是否合适 pinctrl 是否正确 reg 地址是否正确 compatible 是否和驱动匹配 触摸 IC 电源和 reset 是否先准备好`

---

**SPI 子系统架构**

SPI 架构和 I2C 类似：

`SPI controller / master ↓ SPI core ↓ SPI device driver ↓ 触摸 IC`

核心对象：

`struct spi_controller / spi_master 表示 SPI 控制器 struct spi_device 表示 SPI 从设备 struct spi_driver 表示 SPI 设备驱动 struct spi_transfer 表示一段 SPI 传输 struct spi_message 表示一次完整 SPI 消息`

SPI 驱动注册：

`static struct spi_driver xxx_spi_driver = { .driver = { .name = "xxx_touch", .of_match_table = xxx_of_match, }, .probe = xxx_spi_probe, .remove = xxx_spi_remove, }; module_spi_driver(xxx_spi_driver);`

设备树：

`&spi0 { status = "okay"; touchscreen@0 { compatible = "ilitek,ili9881h"; reg = <0>; // chip select 0 spi-max-frequency = <10000000>; reset-gpios = <&pio 12 GPIO_ACTIVE_HIGH>; irq-gpios = <&pio 13 GPIO_ACTIVE_LOW>; }; };`

---

**SPI 常见传输接口**

简单同步传输：

`spi_sync(spi, &msg);`

写：

`spi_write(spi, txbuf, len);`

读：

`spi_read(spi, rxbuf, len);`

全双工：

`spi_write_then_read(spi, txbuf, txlen, rxbuf, rxlen);`

完整 message：

`struct spi_transfer xfer = { .tx_buf = txbuf, .rx_buf = rxbuf, .len = len, }; struct spi_message msg; spi_message_init(&msg); spi_message_add_tail(&xfer, &msg); ret = spi_sync(spi, &msg);`

SPI 设备参数：

`spi->mode = SPI_MODE_0; spi->bits_per_word = 8; spi->max_speed_hz = 10000000; spi_setup(spi);`

---

**SPI mode 是什么**

SPI mode 由 CPOL 和 CPHA 决定：

`SPI_MODE_0：CPOL=0, CPHA=0 SPI_MODE_1：CPOL=0, CPHA=1 SPI_MODE_2：CPOL=1, CPHA=0 SPI_MODE_3：CPOL=1, CPHA=1`

含义：

`CPOL：时钟空闲时是高还是低 CPHA：在哪个时钟边沿采样`

如果 mode 配错，会出现：

`读 ID 失败 数据错位 偶发通信错误 全 0 或全 FF`

---

**I2C vs SPI 在面试中的对比**

可以这样答：

`I2C 使用地址寻址，同一总线可挂多个设备，线少，但速度较低，协议开销更大。 SPI 使用片选 CS 区分设备，速度更高，可以全双工，但线更多，也需要配置 mode、bits_per_word、max_speed_hz。 触摸屏如果数据量较小常用 I2C，如果报点率高或数据量大，也可能使用 SPI。`

---

**通信和 Input 上报的关系**

I2C/SPI 子系统只负责“把数据拿回来或写出去”。  
它不理解触摸坐标，也不负责生成 /dev/input/eventX。

触摸驱动要做三件事：

`1. 通过 I2C/SPI 读取原始触摸包 2. 按芯片协议解析坐标、id、状态、校验 3. 通过 Input 子系统上报标准事件`

典型代码结构：

`static irqreturn_t xxx_irq_thread(int irq, void *dev_id) { struct xxx_ts *ts = dev_id; u8 buf[128]; ret = xxx_bus_read(ts, TOUCH_DATA_CMD, buf, sizeof(buf)); if (ret < 0) return IRQ_HANDLED; xxx_parse_touch_data(ts, buf); xxx_report_points(ts); return IRQ_HANDLED; }`

很多厂商驱动会封装 bus ops：

`struct xxx_bus_ops { int (*read)(u8 *cmd, int cmdlen, u8 *data, int datalen); int (*write)(u8 *data, int len); };`

这样同一套核心逻辑可以同时支持 I2C 和 SPI。

---

**触摸 IC 常见通信内容**

触摸驱动通过 I2C/SPI 不只读坐标，还可能做：

`读取 chip id 读取 firmware version 读取 protocol version 切换 normal / sleep / gesture 模式 读取触摸坐标数据 固件升级 ESD 检测 校准或自检 写入配置参数 读取 raw data / diff data`

你打开的 ilitek_v3_flash.c 就大概率和固件升级有关，里面会有大量 I2C/SPI 写 flash、读校验、切模式的逻辑。

---

**电源和 reset 对通信的影响**

I2C/SPI 通信成功的前提通常是：

`电源打开 reset 时序正确 pinctrl 配置正确 IC boot 完成 总线控制器工作 地址/mode/频率正确`

触摸 probe 常见顺序：

`解析 dts ↓ 获取 regulator / gpio / pinctrl ↓ 上电 ↓ reset ↓ 等待 IC 启动 ↓ 通过 I2C/SPI 读 chip id ↓ 注册 input ↓ 申请 irq`

如果一上来就读 I2C，IC 还没出 reset，很容易读失败。

---

**调试 I2C**

常用命令：

`i2cdetect -y 1 i2cdump -y 1 0x41 i2cget -y 1 0x41 0x00`

Android/嵌入式平台可能没有这些工具，可以看：

`dmesg | grep -i i2c dmesg | grep -i ilitek cat /sys/kernel/debug/pinctrl/*/pinmux-pins cat /proc/interrupts`

注意：  
i2cdetect 可能干扰设备，某些触摸 IC 不适合随便扫，尤其量产设备上要谨慎。

---

**调试 SPI**

常用检查点：

`spi controller 是否 probe 设备树 compatible 是否匹配 CS 是否正确 spi-max-frequency 是否过高 SPI mode 是否正确 MOSI/MISO/SCLK/CS pinctrl 是否正确 读 chip id 是否稳定`

相关 log：

`dmesg | grep -i spi dmesg | grep -i ilitek`

可以通过逻辑分析仪看：

`SCLK 是否有波形 CS 是否拉低 MOSI 是否有命令 MISO 是否有响应 mode 是否采样正确 频率是否符合规格`

---

**结合触摸驱动的面试说法**

可以这样完整回答：

> I2C/SPI 子系统在触摸驱动中主要负责主控和触摸 IC 之间的通信。设备树会在对应的 I2C 或 SPI controller 下描述触摸 IC，I2C core 或 SPI core 根据 compatible 匹配驱动并调用 probe。probe 阶段驱动会上电、reset，然后通过 I2C/SPI 读取 chip id 或 firmware version 确认设备在线。运行时，触摸 IC 通过 GPIO IRQ 通知主控有数据，驱动在线程化中断中通过 I2C/SPI 读取触摸数据包，解析出每个触点的 id、x、y、pressure，再调用 Input 子系统接口上报事件。由于 I2C/SPI 通信可能睡眠，所以不能放在硬中断里，一般使用 threaded irq 或 workqueue。I2C 线少、有地址、速度相对低；SPI 速度更高、全双工，但需要 CS 和 mode 配置。