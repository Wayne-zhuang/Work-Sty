
[[Linux 子系统汇总]]

workqueue 是 Linux 内核里的异步执行机制。  
它的核心作用是：**把当前不适合立即执行的工作，丢到内核线程上下文里稍后执行**。

常见使用场景：

`中断里不能睡眠，但后续操作需要睡眠 某些任务比较耗时，不适合阻塞当前路径 需要延迟执行，比如 ESD check、固件升级后 reset 需要周期性任务，比如触摸 IC 健康检查`

触摸屏驱动里经常用 workqueue 做：

`触摸中断后异步读 I2C/SPI 数据 ESD 检测 固件升级 异常恢复 reset 上电初始化后延迟任务 resume 后重新初始化 debug/proc 触发的异步操作`

---

**为什么不能什么都在中断里做**

硬中断上下文限制很多：

`不能睡眠 不能执行可能阻塞的 I2C/SPI/regulator 操作 不能长时间运行 不能拿可能睡眠的 mutex`

而触摸驱动中很多操作都会睡眠：

`I2C/SPI 传输 regulator_enable msleep firmware request mutex_lock`

所以需要：

`threaded irq workqueue kthread`

把工作放到进程上下文执行。

---

**Workqueue 和 threaded irq 的区别**

触摸屏常见两种方式：

**方式 1：threaded irq**

`devm_request_threaded_irq(dev, irq, NULL, ts_irq_thread, IRQF_ONESHOT, "touch_irq", ts);`

中断后直接在线程化中断里读数据、上报 input。

特点：

`简单直接 适合 IRQ 来一次处理一次 线程上下文，可以睡眠 很多触摸屏驱动首选`

**方式 2：hard irq + workqueue**

`static irqreturn_t ts_irq_handler(int irq, void *dev_id) { struct ts_data *ts = dev_id; queue_work(ts->wq, &ts->event_work); return IRQ_HANDLED; }`

work 里读数据：

`static void ts_event_work(struct work_struct *work) { struct ts_data *ts = container_of(work, struct ts_data, event_work); ts_read_touch_data(ts); ts_report_input(ts); }`

特点：

`更灵活 可以合并任务 可以复用同一个工作队列处理不同事件 需要自己处理重复 queue、disable irq、状态同步`

面试可以答：

> 触摸屏里如果中断处理需要 I2C/SPI 读数据，不能放硬中断里。可以用 threaded irq，也可以在中断里 queue_work，让 workqueue 在线程上下文完成读数据和 input 上报。

---

**work_struct 基本用法**

定义：

`struct work_struct event_work;`

初始化：

`INIT_WORK(&ts->event_work, ts_event_work);`

提交：

`queue_work(ts->wq, &ts->event_work);`

执行函数：

`static void ts_event_work(struct work_struct *work) { struct ts_data *ts; ts = container_of(work, struct ts_data, event_work); /* do something */ }`

创建队列：

`ts->wq = create_singlethread_workqueue("touch_wq");`

销毁：

`destroy_workqueue(ts->wq);`

取消：

`cancel_work_sync(&ts->event_work);`

如果不需要单独队列，也可以用系统队列：

`schedule_work(&ts->event_work);`

---

**delayed_work**

delayed_work 用于延迟执行，触摸驱动里很常见。

例如 ESD check：

`struct delayed_work esd_work;`

初始化：

`INIT_DELAYED_WORK(&ts->esd_work, ts_esd_work);`

启动：

`queue_delayed_work(ts->wq, &ts->esd_work, msecs_to_jiffies(2000));`

work 里重新排队，实现周期任务：

`static void ts_esd_work(struct work_struct *work) { struct ts_data *ts; ts = container_of(to_delayed_work(work), struct ts_data, esd_work); ts_check_esd(ts); queue_delayed_work(ts->wq, &ts->esd_work, msecs_to_jiffies(2000)); }`

取消：

`cancel_delayed_work_sync(&ts->esd_work);`

---

**为什么触摸驱动需要并发保护**

触摸驱动里会有很多路径同时访问同一个触摸 IC：

`IRQ 线程：读取触摸坐标 
`ESD work：定期读寄存器 proc/sysfs：
`用户触发 rawdata、fw version、reset 
`suspend/resume：切换模式、开关电源、enable/disable irq 
`firmware upgrade：进入 bootloader、写 flash 
`remove/shutdown：释放资源`

这些路径如果同时操作，会出问题：

`I2C/SPI 命令交叉 
`固件升级时中断线程也在读触摸数据 
`suspend 关电时 proc 还在读 rawdata 
`reset 时 ESD work 同时读寄存器 
`input_dev 已释放但 work 还没退出`

所以必须用锁和状态位保护。

---

**Mutex 是什么**

mutex 是互斥锁，用来保护临界区，保证同一时间只有一个线程访问共享资源。

特点：

`mutex 可能睡眠 只能在进程上下文使用 不能在硬中断上下文使用 适合保护 I2C/SPI、状态机、固件升级、suspend/resume 等路径`

基本用法：

`struct mutex touch_mutex; 
`mutex_init(&ts->touch_mutex); 
`mutex_lock(&ts->touch_mutex); 
`/* critical section */ 
`mutex_unlock(&ts->touch_mutex);`

销毁：

`mutex_destroy(&ts->touch_mutex);`

如果不想阻塞：

`if (!mutex_trylock(&ts->touch_mutex)) 
	`return -EBUSY;`

---

**Mutex 在触摸驱动里的典型用法**

保护 I2C/SPI 通信：

`mutex_lock(&ts->io_lock); 

`ret = ts_i2c_read(ts, cmd, data, len); 

`mutex_unlock(&ts->io_lock);`

保护模式切换：

`mutex_lock(&ts->mode_lock); 
`ts_enter_gesture_mode(ts); 
`ts->mode = TS_MODE_GESTURE; 
`mutex_unlock(&ts->mode_lock);`

固件升级期间阻止中断读点：

`mutex_lock(&ts->touch_mutex); 

`ts->fw_upgrading = true; 
`disable_irq(ts->irq); 
`ret = ts_fw_upgrade(ts); 
`enable_irq(ts->irq); 
`ts->fw_upgrading = false; 

`mutex_unlock(&ts->touch_mutex);`

中断线程里检查状态：

`mutex_lock(&ts->touch_mutex); 

`if (ts->suspended || ts->fw_upgrading) { 
	`mutex_unlock(&ts->touch_mutex); 
	`return IRQ_HANDLED; 
`} 
`ts_read_touch_data(ts); 
`ts_report_input(ts); 

`mutex_unlock(&ts->touch_mutex);`

---

**Mutex 和 Spinlock 区别**

面试常问。

`mutex： 会睡眠 适合进程上下文 临界区可以比较长 可以保护 I2C/SPI、regulator、sleep 操作 不能在硬中断里用 spinlock： 不睡眠，忙等 可用于中断上下文 临界区必须很短 不能在持锁时睡眠 适合保护简单变量、链表、状态位`

触摸驱动多数核心路径使用 mutex，因为 I2C/SPI 读写和 msleep() 都可能睡眠。

---

**Workqueue 和 Mutex 的组合**

典型组合是：

`IRQ handler 只负责 queue_work workqueue 里 mutex_lock mutex 保护 I2C/SPI 和状态 work 完成后 input_sync`

示例：

`static irqreturn_t ts_irq_handler(int irq, void *dev_id) { 
`struct ts_data *ts = dev_id; 
`if (ts->suspended) 
	`return IRQ_HANDLED; 
	`queue_work(ts->wq, &ts->event_work); 
	`return IRQ_HANDLED; 
`} 

`static void ts_event_work(struct work_struct *work) { 
	`struct ts_data *ts; ts = container_of(work, struct ts_data, event_work); mutex_lock(&ts->touch_mutex); 
	`if (!ts->suspended && !ts->fw_upgrading) { 
		`ts_read_touch_data(ts); 
		`ts_report_input(ts); 
	`} 
	`mutex_unlock(&ts->touch_mutex); 
`}`

注意：

`如果中断频繁，需要考虑 work 是否重复排队 必要时 disable_irq_nosync，work 结束后 enable_irq`

---

**disable_irq 和 workqueue**

触摸中断场景中常见：

`disable_irq_nosync(ts->irq); 
`queue_work(ts->wq, &ts->event_work);`

work 结束：

`enable_irq(ts->irq);`

这样避免同一个中断在 work 还没处理完时重复进来。

区别：

`disable_irq() 等待正在执行的中断 handler 结束，可能睡眠 disable_irq_nosync() 不等待当前 handler 结束，可在中断上下文使用`

在硬中断 handler 里通常用：

`disable_irq_nosync()`

---

**flush_work 和 cancel_work_sync**

移除驱动或 suspend 时，要保证 work 不再运行。

`cancel_work_sync(&ts->event_work); 
`cancel_delayed_work_sync(&ts->esd_work);`

区别：

`flush_work： 等待已经排队的 work 执行完成，不取消未来重新排队 cancel_work_sync： 取消未执行的 work；如果正在执行，等待执行结束 cancel_delayed_work_sync： delayed_work 版本`

remove/shutdown 前必须处理，否则可能出现：

`use-after-free 设备已下电但 work 还在 I2C input_dev 已释放但 work 还在上报`

---

**死锁问题**

常见死锁场景：

**1. 锁顺序不一致**

路径 A：

`lock io_lock lock mode_lock`

路径 B：

`lock mode_lock lock io_lock`

可能死锁。

解决：

`统一锁顺序 减少多锁嵌套`

**2. 持 mutex 后 cancel_work_sync，而 work 也要拿同一把 mutex**

错误示例：

`mutex_lock(&ts->touch_mutex); 
`cancel_work_sync(&ts->event_work); 
`mutex_unlock(&ts->touch_mutex);`

如果 event_work 正在运行，并且正在等 touch_mutex，就可能死锁。

正确思路：

`先阻止新 work 进入 cancel_work_sync 再加锁修改状态`

或者保证 work 不会拿同一把锁。

**3. 硬中断里拿 mutex**

错误：

`static irqreturn_t irq_handler(...) { 
	`mutex_lock(&ts->touch_mutex); `// 错 
`}`

硬中断不能睡眠。

---

**状态位也很重要**

锁不是全部，状态位也很关键：

`bool suspended; 
`bool fw_upgrading; 
`bool gesture_enabled; 
`bool esd_running; 
`bool irq_enabled;`

典型判断：

`mutex_lock(&ts->touch_mutex); 

`if (ts->suspended && !ts->gesture_enabled) 
	`goto out; 
`if (ts->fw_upgrading) 
	`goto out; 
	
`ret = ts_read_touch_data(ts); 

`out: mutex_unlock(&ts->touch_mutex);`

面试可以说：

> 触摸驱动不仅靠 mutex，还要结合状态机。比如 suspended、gesture、fw_upgrading、esd_check_running 等状态决定当前路径是否允许访问 IC。

---

**和 suspend/resume 的关系**

suspend 时常见处理：

`1. 设置 suspended 状态 
`2. 停止 ESD delayed_work 
`3. disable irq 或切 gesture irq wake 
`4. cancel 正在运行的 work 
`5. 进入 sleep/gesture mode 
`6. 必要时关闭 regulator`

resume 时：

`1. 打开 regulator 
`2. pinctrl default 
`3. reset/init IC 
`4. 清 suspended 状态 
`5. enable irq 
`6. 重启 ESD delayed_work`

代码形态：

`static int ts_suspend(struct device *dev) { 
	`struct ts_data *ts = dev_get_drvdata(dev); 
	`ts->suspended = true; 
	`cancel_delayed_work_sync(&ts->esd_work); 
	`disable_irq(ts->irq); 
	`mutex_lock(&ts->touch_mutex); 
	`ts_enter_sleep(ts); 
	`mutex_unlock(&ts->touch_mutex); 
	`return 0; 
`}`

要注意顺序，避免：

`刚 suspend 关电，event_work 又被调度起来访问 I2C`

---

**固件升级场景**

固件升级最需要并发保护，因为它会长时间占用 IC。

典型流程：

`disable irq 
`cancel event work 
`cancel esd work 
`mutex_lock 
`设置 fw_upgrading 
`进入 bootloader 
`擦写 flash 
`校验 
`reset IC 
`清 fw_upgrading 
`mutex_unlock 
`enable irq 
`重启 esd work`

如果不保护，可能出现：

`升级过程中 IRQ 线程读取触摸数据 
`ESD work 认为 IC 异常并 reset 
`proc rawdata 和升级命令冲突 
`suspend 打断升级`

---

**触摸驱动中常见锁分类**

可以按职责分：

`io_lock： 
	`保护 I2C/SPI 总线访问，防止命令交叉 
	
`touch_mutex： 
	`保护触摸状态和报点流程 
	
`fw_mutex： 
	`保护固件升级流程 
	
`debug_mutex： 
	`保护 proc/sysfs debug buffer 
	
`mode_mutex： 
	`保护 normal/sleep/gesture/test mode 切换`

实际项目不一定分这么细。小驱动可能一把大锁，大驱动会分多把锁。

面试上可以说：

> 锁粒度要平衡。太粗会影响响应和并发，太细会增加死锁风险。触摸驱动一般至少要保护总线访问和模式切换。

---

**调试 workqueue/mutex 问题**

常用 log：

`dmesg | grep -i work 
`dmesg | grep -i hung 
`dmesg | grep -i blocked`

查看线程：

`ps -A | grep kworker 
`ps -A | grep irq`

查看中断：

`cat /proc/interrupts`

内核调试配置：

`CONFIG_LOCKDEP 
`CONFIG_PROVE_LOCKING 
`CONFIG_DEBUG_MUTEXES 
`CONFIG_DETECT_HUNG_TASK 
`CONFIG_WQ_WATCHDOG`

典型问题表现：

`触摸偶现卡死 
`suspend/resume 卡住 
`cat proc 节点不返回 
`固件升级中死机 
`系统提示 hung task 
`lockdep 报 circular locking dependency`

---

**结合 ILITEK 触摸驱动怎么说**

你可以在 ILITEK 代码里重点搜：

`INIT_WORK 
`INIT_DELAYED_WORK 
`queue_work 
`schedule_work 
`queue_delayed_work 
`cancel_work_sync 
`cancel_delayed_work_sync 
`flush_work 
`mutex_init 
`mutex_lock 
`mutex_unlock 
`disable_irq 
`enable_irq 
`fw_upgrade 
`esd 
`gesture 
`suspend 
`resume`

面试时结合项目可以这样讲：

> 在触摸屏驱动中，workqueue 主要用于把不能在中断上下文中执行的任务放到进程上下文处理，比如 I2C/SPI 读触摸数据、ESD 检测、异常 reset、固件升级后的恢复等。因为触摸 IC 会被 IRQ 线程、ESD work、proc/sysfs、suspend/resume、firmware upgrade 多条路径访问，所以需要 mutex 做并发保护，防止 I2C/SPI 命令交叉、下电时仍访问 IC、升级时被中断读点打断。硬中断里不能拿 mutex，也不能做 I2C/SPI 通信；可以用 threaded irq 或 queue_work。remove/suspend 前要 cancel_work_sync 或 cancel_delayed_work_sync，避免设备释放或下电后 work 继续运行。