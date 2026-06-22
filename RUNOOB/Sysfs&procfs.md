
[[Linux 子系统汇总]]

**Sysfs 和 Procfs 是什么**

sysfs 和 procfs 都是 Linux 内核向用户空间暴露信息的虚拟文件系统。  
它们不是真正存储在磁盘上的文件，而是内核动态生成的接口。

常见挂载点：

`/proc -> procfs /sys -> sysfs`

一句话区分：

`procfs：早期主要用于进程和内核运行状态信息，也常被驱动拿来做调试接口。 sysfs：基于 Linux device model，按设备、总线、驱动、class、属性组织，更适合标准设备属性。`

---

**procfs 主要做什么**

procfs 最初是为了暴露进程信息：

`/proc/1/ /proc/cpuinfo /proc/meminfo /proc/interrupts /proc/kmsg /proc/modules`

后来很多驱动也会在 /proc 下创建调试节点，例如：

`/proc/ilitek /proc/ilitek_debug /proc/touchpanel /proc/tp_info`

触摸屏厂商驱动常喜欢用 procfs 做：

`读 firmware version 读 chip id 触发固件升级 读 raw data / diff data 切换 debug mode 读取 selftest 结果 开关 gesture 查看 ESD 状态`

---

**sysfs 主要做什么**

sysfs 是 Linux device model 的用户空间表现。  
它反映内核中的设备、驱动、总线、class 关系。

常见路径：

`/sys/devices/ /sys/bus/ /sys/class/ /sys/module/ /sys/kernel/`

比如 input 设备：

`/sys/class/input/inputX/ /sys/class/input/eventX/`

I2C 设备：

`/sys/bus/i2c/devices/1-0041/`

驱动：

`/sys/bus/i2c/drivers/ilitek/`

sysfs 适合暴露设备属性，例如：

`fw_version chip_id gesture_enable reset power_state`

---

**procfs 和 sysfs 的核心区别**

`procfs： 偏运行状态、进程信息、调试信息 历史包袱较多 驱动厂商常用于复杂 debug 接口格式相对自由 sysfs： 和 device model 强绑定 一个文件通常表示一个属性 更适合标准化设备属性 推荐简单、清晰、稳定的 ABI`

面试可以这样说：

> 新驱动如果是暴露设备属性，优先考虑 sysfs；如果是临时调试或复杂 dump，可能用 debugfs；procfs 现在不推荐作为普通驱动新增 ABI，但很多 vendor 驱动历史上仍然大量使用 procfs。

这里顺便提一下 debugfs：

`debugfs：专门用于调试接口，不保证 ABI 稳定，常放 rawdata、寄存器 dump、trace 开关。`

---

**procfs 常用 API**

老内核常见：

`create_proc_entry();`

新内核常见：

`proc_create(); proc_create_data(); remove_proc_entry(); proc_remove();`

常见写法：

`static const struct proc_ops ilitek_proc_ops = { .proc_read = ilitek_proc_read, .proc_write = ilitek_proc_write, }; proc_create("ilitek_debug", 0666, NULL, &ilitek_proc_ops);`

读回调：

`static ssize_t ilitek_proc_read(struct file *file, char __user *buf, size_t count, loff_t *ppos) { char tmp[128]; int len; len = snprintf(tmp, sizeof(tmp), "fw=0x%x\n", fw_ver); return simple_read_from_buffer(buf, count, ppos, tmp, len); }`

写回调：

`static ssize_t ilitek_proc_write(struct file *file, const char __user *buf, size_t count, loff_t *ppos) { char tmp[32]; if (count >= sizeof(tmp)) return -EINVAL; if (copy_from_user(tmp, buf, count)) return -EFAULT; tmp[count] = '\0'; if (sysfs_streq(tmp, "reset")) ilitek_hw_reset(); return count; }`

注意：  
Linux 5.6 以后很多地方从 file_operations 切到 proc_ops。

---

**sysfs 常用 API**

sysfs 属性通常通过 DEVICE_ATTR 创建。

读属性：

`static ssize_t fw_version_show(struct device *dev, struct device_attribute *attr, char *buf) { return sysfs_emit(buf, "0x%x\n", fw_ver); }`

写属性：

`static ssize_t gesture_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count) { bool enable; int ret; ret = kstrtobool(buf, &enable); if (ret) return ret; ts->gesture_enabled = enable; return count; }`

定义属性：

`static DEVICE_ATTR_RO(fw_version); static DEVICE_ATTR_RW(gesture);`

创建文件：

`device_create_file(dev, &dev_attr_fw_version); device_create_file(dev, &dev_attr_gesture);`

移除文件：

`device_remove_file(dev, &dev_attr_fw_version); device_remove_file(dev, &dev_attr_gesture);`

更推荐属性组：

`static struct attribute *ilitek_attrs[] = { &dev_attr_fw_version.attr, &dev_attr_gesture.attr, NULL, }; static const struct attribute_group ilitek_attr_group = { .attrs = ilitek_attrs, }; sysfs_create_group(&dev->kobj, &ilitek_attr_group);`

移除：

`sysfs_remove_group(&dev->kobj, &ilitek_attr_group);`

---

**sysfs 文件设计原则**

sysfs 有一个重要原则：

`一个文件表达一个属性`

好的例子：

`/sys/.../fw_version /sys/.../gesture_enable /sys/.../chip_id`

不太好的例子：

`/sys/.../debug_command`

更不好的例子：

`/sys/.../everything`

读写格式通常应该简单：

`0 1 0x1234 normal gesture`

读函数应该用：

`sysfs_emit(buf, ...)`

不要用不安全的 sprintf。

写函数解析用户输入时常用：

`kstrtoint() kstrtou32() kstrtobool() sysfs_streq()`

---

**procfs 文件设计特点**

procfs 厂商驱动里经常是命令式接口：

`echo reset > /proc/ilitek echo fw_upgrade > /proc/ilitek cat /proc/ilitek`

或者：

`echo 0xF6 0x01 > /proc/ilitek_cmd cat /proc/ilitek_rawdata`

这类接口灵活，但问题也明显：

`ABI 不规范 权限风险高 格式不统一 用户空间依赖后难维护 多线程并发容易出问题`

面试可以说：

> Vendor 驱动中 procfs 常用于产测和调试，但如果要做长期稳定接口，更推荐 sysfs 或标准子系统接口；如果只是 debug，则 debugfs 更合适。

---

**权限和安全**

创建文件时会设置权限：

`proc_create("ilitek_debug", 0666, NULL, &ops);`

或者 sysfs：

`static DEVICE_ATTR_RW(gesture); // 通常 0644`

常见权限：

`0444 只读 0644 root 可写，所有人可读 0600 root 读写 0666 所有人可读写，不推荐`

触摸驱动里如果给了 0666，用户空间任意进程都可能触发 reset、升级固件、读写寄存器，风险很高。

面试可以提：

> 涉及 reset、固件升级、寄存器读写的接口应限制权限，避免普通应用随意操作硬件。

---

**并发和上下文问题**

sysfs/procfs 的 read/write 是用户进程上下文，可以睡眠。  
所以里面可以做 I2C/SPI 通信、mutex 加锁、等待完成等。

但要注意并发：

`用户正在 cat rawdata 同时触摸中断也在读数据 同时 suspend 正在发生 同时固件升级正在进行`

所以驱动里常见保护：

`mutex_lock(&ts->touch_mutex); ... mutex_unlock(&ts->touch_mutex);`

或者：

`disable_irq(ts->irq); ... enable_irq(ts->irq);`

固件升级时可能还要阻止正常报点：

`设置 fw_update_stat 停止 ESD check disable irq 进入 bootloader 升级 reset enable irq 恢复 ESD check`

---

**读写用户空间 buffer 的注意点**

procfs 的 read/write 涉及用户空间指针：

`copy_from_user() copy_to_user() simple_read_from_buffer()`

不能直接访问：

`memcpy(kernel_buf, user_buf, count); // 错`

sysfs 的 store 入参 const char *buf 已经是内核缓冲区，不需要 copy_from_user()。

区别：

`procfs write: buf 是 __user 指针，需要 copy_from_user sysfs store: buf 是内核态 buffer，可以直接解析`

这是面试容易问的细节。

---

**和 Input 子系统的关系**

Input 子系统负责标准事件上报：

`/dev/input/eventX`

sysfs/procfs 通常负责非标准控制和调试：

`查看固件版本 触发 reset 开关 gesture 读 rawdata 固件升级 产测`

比如：

`正常触摸坐标：通过 input event 上报 调试 rawdata：通过 procfs/debugfs/sysfs 读取 gesture enable：可能通过 sysfs/procfs 配置`

不要把正常触摸坐标通过 procfs 给 Android 用，这是不符合输入框架设计的。

---

**触摸驱动常见 proc/sys 节点**

厂商触摸驱动常见：

`/proc/ilitek/version /proc/ilitek/fw_upgrade /proc/ilitek/rawdata /proc/ilitek/debug_message /proc/ilitek/mp_test /proc/touchpanel/chip_info /proc/touchpanel/baseline_test`

sysfs 常见：

`/sys/bus/i2c/devices/1-0041/fw_version /sys/bus/i2c/devices/1-0041/gesture /sys/bus/i2c/devices/1-0041/reset /sys/class/input/inputX/name /sys/class/input/inputX/capabilities/*`

Android 上还可能有厂商自定义路径：

`/proc/touchpanel/ sys/class/touchscreen/`

具体取决于项目规范。

---

**调试命令**

查看 proc：

`ls /proc cat /proc/interrupts cat /proc/bus/input/devices cat /proc/modules`

查看 sysfs：

`ls /sys/class/input/ cat /sys/class/input/input*/name cat /sys/class/input/input*/uevent cat /sys/bus/i2c/devices/*/name`

查触摸节点：

`find /proc -iname "*ili*" -o -iname "*touch*" find /sys -iname "*ili*" -o -iname "*touch*"`

Android：

`adb shell cat /proc/bus/input/devices adb shell getevent -lp adb shell find /proc -iname "*touch*" adb shell find /sys -iname "*touch*"`

---

**常见问题**

**1. 节点没有创建**

排查：

`proc_create/sysfs_create_group 是否执行 probe 是否成功 权限/路径是否正确 CONFIG_PROC_FS 是否开启 sysfs group 创建是否返回错误`

**2. cat 节点卡住**

可能：

`read 回调没有正确处理 ppos 等待硬件响应超时 mutex 死锁 I2C/SPI 卡住`

procfs read 要注意 *ppos，否则可能重复输出或 cat 不结束。  
用 simple_read_from_buffer() 能减少这类问题。

**3. echo 后无效**

可能：

`store/write 解析字符串失败 没有处理换行 权限不足 驱动状态不允许操作，比如 suspend 中`

解析字符串时要考虑用户输入通常带 \n：

`echo 1 > gesture`

内核收到可能是：

`"1\n"`

所以常用：

`kstrtobool(buf, &enable); sysfs_streq(buf, "reset");`

**4. 并发导致触摸异常**

可能：

`proc 节点读 rawdata 时和 irq 抢 I2C fw upgrade 时没有 disable irq suspend 和 proc 操作同时发生`

解决：

`mutex 保护 状态机判断 disable_irq pm_runtime_get_sync`

---

**结合 ILITEK 触摸驱动怎么讲**

你这个 ILITEK 驱动大概率会有 procfs 节点，因为很多触摸厂商驱动会用 /proc 做固件升级、MP test、debug message、raw data 读取。

你可以在代码里重点搜：

`proc_create proc_mkdir remove_proc_entry proc_ops file_operations DEVICE_ATTR device_create_file sysfs_create_group kobject_create_and_add`

面试时可以这样说：

> 在触摸驱动中，Input 子系统负责标准触摸事件上报，用户空间通过 /dev/input/eventX 获取坐标；而 sysfs/procfs 通常用于调试和控制，比如读取 chip id、firmware version、rawdata，触发固件升级或 MP 测试，开关 gesture。sysfs 更适合暴露单一设备属性，路径跟 device model 绑定；procfs 更多是历史上厂商驱动用于复杂调试命令。实现时要注意权限、用户 buffer 拷贝、read 的 ppos 处理，以及和 IRQ、suspend、firmware upgrade 的并发互斥。