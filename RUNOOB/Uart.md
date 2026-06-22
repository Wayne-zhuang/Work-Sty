[[通信总线]]

[基于Linux的tty架构及UART驱动详解 - 一口Linux - 博客园](https://www.cnblogs.com/yikoulinux/p/14507445.html)

UART 是异步串口通信，通常只有 TX/RX/GND，没有时钟线，双方靠相同波特率通信。常见配置包括：

baudrate
data bits
stop bits
parity
flow control
工作中 UART 常见问题有：

波特率不匹配，打印乱码
TX/RX 接反
电平不匹配，比如 1.8V / 3.3V / RS232
没有共地
串口被多个模块复用，pinmux 配错
DMA/中断接收丢数据
低功耗唤醒后串口时钟没恢复
日志量太大导致 FIFO overflow
比如调试串口乱码，我一般先确认波特率、数据位、停止位、校验位，再看电平和波形。如果波形正常但内容错，通常是配置问题；如果波形幅值不对，可能是电平或硬件连接问题。

UART 驱动里还会关注 FIFO、中断、DMA、流控。大量数据场景下，如果只靠中断逐字节接收，CPU 压力会比较大，容易丢数据，所以会用 DMA 或加大环形缓冲。