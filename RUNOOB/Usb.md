[[通信总线]]
[Linux usb子系统（一）：子系统架构 - CSlunatic - 博客园](https://www.cnblogs.com/cslunatic/p/3726053.html)

## ==usb枚举

主机  集线器 设备
主机只有一个 通信只能由主机发起，主要工作是设备枚举 带宽设置 数据传输调度
集线器 主要用来拓展usb接口，端口管理 电源管理 信号中继
设备就是鼠标 键盘这些一个设备可以有一个ep 或者多个ep

设备枚举过程
设备插入usb端口 检测(d+或d-上拉)电气特性发生变化 集线器检测变化通过中断传输到主机
主机发起复位，设备进入默认状态，使用默认地址0进行通信
发起get_discrotper请求,获取前八位设备描述符，主要是为了ep0的最大包长度
有些主机会再次发起复位
分配新地址
使用新地址通信，获取完整的设备描述符，vid pid 设备描述信息等等
配置描述 成功绑定

 1. 设备连接与检测                                                                                                     …
  - 设备插入 USB 端口，Hub 检测到 D+/D- 线上的电平变化
  - Hub 通过中断端点通知主机有新设备接入

  2. 主机获取设备速度

  - 根据 D+/D- 上拉电阻的位置判断设备速度：
    - D+ 上拉 → Full Speed (12 Mbps)
    - D- 上拉 → Low Speed (1.5 Mbps)
    - High Speed 设备先以 Full Speed 连接，再通过 Chirp 协商切换到 480 Mbps

  3. 总线复位（Bus Reset）

  - 主机向设备发送 Reset 信号（SE0 持续 10~20ms）
  - 复位后设备使用默认地址 0

  4. 第一次获取设备描述符

  - 主机发送 GET_DESCRIPTOR（Device Descriptor）到地址 0
  - 通常只读取前 8 字节，目的是获取 bMaxPacketSize0（端点 0 的最大包大小）

  5. 再次复位

  - 主机对设备再次发送 Bus Reset

  6. 分配地址（Set Address）

  - 主机发送 SET_ADDRESS 请求，为设备分配唯一地址（1~127）
  - 此后设备使用新地址通信

  7. 第二次获取设备描述符

  - 主机用新地址重新读取完整的设备描述符（18 字节）

  8. 获取配置描述符

  - 主机发送 GET_DESCRIPTOR（Configuration Descriptor）
  - 先读取前 9 字节获取 wTotalLength
  - 再读取完整配置（包含接口描述符、端点描述符等）

  9. 获取字符串描述符（可选）

  - 读取厂商名、产品名、序列号等字符串信息

  10. 设置配置（Set Configuration）

  - 主机发送 SET_CONFIGURATION，激活某个配置
  - 设备进入 Configured 状态，枚举完成

  流程示意

  设备插入
    │
    ▼
  Hub 检测 → 通知主机
    │
    ▼
  Bus Reset（设备地址=0）
    │
    ▼
  GET_DESCRIPTOR（8字节，获取 MaxPacketSize）
    │
    ▼
  Bus Reset
    │
    ▼
  SET_ADDRESS（分配地址 1~127）
    │
    ▼
  GET_DESCRIPTOR（完整设备描述符）
    │
    ▼
  GET_DESCRIPTOR（配置描述符）
    │
    ▼
  GET_DESCRIPTOR（字符串描述符，可选）
    │
    ▼
  SET_CONFIGURATION → 枚举完成

  关键点

  - 所有控制传输都通过**端点 0（EP0）**进行
  - 枚举使用的是控制传输（Setup → Data → Status 三阶段）
  - 如果任何步骤失败，主机会重试（通常 3 次），失败则放弃枚举
  - Windows/Linux 等操作系统在枚举后还会加载对应的设备驱动程序