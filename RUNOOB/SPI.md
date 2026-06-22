[[通信总线]]

[SPI总线协议及SPI时序图详解 - Ady Lee - 博客园](https://www.cnblogs.com/adylee/p/5399742.html)



![[spi时序图.png]]

==spi工作模式:

CPOL位表示初始时钟极性：

CPOL = 0表示时钟初始为低电平，所以开始的第一（leading）边缘是上升沿，第二边缘（trailing）是下降沿。

CPOL = 1时的时钟启动为高电平，所以第一（leading）的边缘是下降沿。

CPHA的指示用于采样数据的时钟相位（注意是采样数据，采样是指的将数据线上的数据锁存起来）

CPHA = 0时表示边沿超前

CPHA = 1表示边沿滞后

==举例spi：

spi_device设备

spi_board_info

init入口调用，spi_register_board_info(S3C_SPI_devs,ARRAY_SIZE(S3C_SPI_devs));

会把spi_board_info注册到board_list链表上。

之后会创建并注册spi_device

spi_driver驱动

1 声明并设置spi_driver结构体

2 注册spi_register_driver(&spi_driver);

3 实现probe操作，spi_transfer,spi_message的构建

spi_message_init,spi_message_add_tail,spi_sync调用

3.1 定义并设置 spi_transfer结构体

3.2 定义spi_message结构体

3.3 初始化meg，spi_message_init(&meg);

3.4 将st放入message队列spi_message_add_tail(&st,&meg);

3.5将message与spi_device关联，发送meg，spi_sync(spi_device,&meg)