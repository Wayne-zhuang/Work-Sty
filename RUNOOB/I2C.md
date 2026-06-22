
[[通信总线]]

[[I2C]I2C总线协议图解 - aaronGao - 博客园](https://www.cnblogs.com/aaronLinux/p/6218660.html)

I2c地址一般是七位 ，左移一位相当于乘以2^1 ,右移 除以2^1 。
从机地址一般要左移一位，还有一位用来做读写位。还有一种方式可以判断厂商提供的地址是7bit模式地址还是8bit地址模式的地址，7bit地址模式下，地址的取值范围在0x07到0x78之间，若超过了这个范围，那么这个地址可能就是8bit地址
I2C设备的写地址 = I2C设备地址 << 1
I2C设备的读地址 = (I2C设备地址 << 1) + 1

引用<<i2c 源代码情景分析>>里的话：“i2c 设备的7 位地址是就当前i2c 总线而言的，是“相对地址”。不同的i2c 总线上的设备可以使用相同的7 位地址，但是它们所在的i2c 总线不同。所以在系统中一个i2c 设备的“绝对地址”由二元组（i2c 适配器的ID 和设备在该总线上的7 位地址）表示。”，所以这个函数的作用主要是排除同一i2c总线上出现多个地址相同的设备

==`iWriteRegI2C(u8 *a_pSendData, u16 a_sizeSendData, u16 i2cId);

功能：读取从机数据
iReadRegI2C函数调用i2c_master_send函数来发送从机寄存器地址，接着调用i2c_master_recv函数来发送读地址并读取寄存器中的值。
参数：
a_pSendData：寄存器的地址
a_sizeSendData：寄存器地址的字节数
a_pRecvData：读取数据存放区
a_sizeRecvData：读取数据字节数
i2cId：读地址

==修改速率

I2C内部上下拉电阻阻值、驱动电流一般在Preloader中i2c.c设定，无需在LK及kernel中配置；但是如果要enable/disable内部上拉，Preloader及DWS都要进行设定
```
/vendor/mediatek/proprietary/bootable/bootloader/preloader/custom/${project}/${project}.mk MTK_I2C_CH0_PULL_DIS=yes
/vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/${platform}/src/drivers/inc/i2c.h
#ifdef MTK_I2C_CH0_PULL_DIS
#undef DIS_CH0_PULL
#define DIS_CH0_PULL 1
#endif
/vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/${platform}/src/drivers/i2c.c
static void pull_up_setting(void)
{
#if DIS_CH0_PULL
#endif
}
int i2c_hw_init(void)
{
......
#ifndef CONFIG_MT_I2C_FPGA_ENABLE
pull_up_setting();
internal_resister_setting();
#endif
return 0;
}

idtable匹配方式

const struct platform_device_id *idtable;

  struct platform_device_id  {
         char name[];  //名字
		 unsigned long driver_data; //给驱动传递的数据
  }
  
MODULE_DEVICE_TABLE(platform,idtable);
//起到热插拔的效果，安装设备时 ，驱动自动安装
  
设备树匹配方式
  const struct of_device_id * of_match_table;
  
  struct of_device_id oftable[] = {
			char compatible[128];
			//按照compatible匹配
			const void *data;
			//给驱动传递的数据
  };
  
  exi:
      struct of_device_id of_table[] = {
	     {.compatible = "sts,duang",},
		 {.compatible = "sts,duang1",},
		 {},  
	  };
  dts:
	   platform{
	      compatible = "sts,duang";
		  reg = <>;
		  interrupt-parent = <&gpiof>;
		  interrupts = <9,0>;	   
	   };
``` 
   
空闲状态下 两根线保持高电平。SCL高电平期间，读数据，SCL拉低，开始数据传输。	   
三种信号：
  起始信号：
     当scl为高电平时，sda从高到低的跳变
  停止信号
     当scl为高电平时，sda从低到高的跳变
  应答信号  
      在第九个时钟周期的时候，sda低电平代表的就是应答信号
	   
两种时序：
   写时序
		start+（7位从机地址 + 1（写0）)+ ack + 8位寄存器地址
		+ ack +8位数据位+ack+stop
	读时序
		start+（7位从机地址 + 1（写0）)+ ack + 8位寄存器地址
		+ ack + start+（7位从机地址 + 1（读1）)+ ack + 从机给主机发送8位数据位
		+ NO ack+stop
半双工 同步串行总线，有应答机制，
速率 100Kbps (低速) 400kbps(全速) 3.4Mbps(高速)


i2c总线驱动
  user ：
      open read write 
-------------------------------
  kernel ：
       1.设备驱动层
	   driver
	     1，为上层提供访问接口 
	     2.封装数据发送数据的过程
-----------------------------------
		2.核心层：内核工程师编写 提供设备驱动 bus和总线驱动注册
		和注销的方式，并完成设备驱动和总线驱动
------------------------------------
        3.总线驱动（控制器驱动）层：厂商编写的驱动，接收设备 device
		驱动发来的数据，然后将这些数据写入到控制器中
i2c
   1.分配对象
   struct i2c_driver {
     int (*probe) (struct i2c_client*client,
	         const struct i2c_device_is *id);
	 //匹配成功执行的函数
	 int (*remove) (struct i2c_client*client};
	 //分离时候执行的函数
	 struct device_driver  driver;
	 //父类中设备树匹配，必须填充name；
	 const struct i2c_device_id *idtable;
	 //iatable匹配
   }
   2.注册 注销
   
   ```
   #define i2c_add_driver(driver) \
      i2c_register_driver(THIS_MODULE,driver)
	
    void i2c_del_driver(struct i2c_driver *driver)
    3.一键注册注销
		module_i2c_driver(变量名)
   ```

i2c封装数据和发送数据的过程
  当设备驱动和总线驱动匹配成功之后创建的结构体，这个
  结构体携带驱动执行需要的各种信息
  
  ```
    struct i2c_client {
	unsigned short flags;
	//读写标志位
	unsigned short addr;  //从机地址
	char name[I2C_NAME_SIZE]; //匹配成功的名字
	struct i2c_adapter *adapter; //总线驱动的对象
	struct device dev; //继承i2c_adapter中的device
  }
  //消息结构体
  struct i2c_msg {
	__u16 addr;  //从机地址 
	__u16 flags;  //1读 0写
	__u16 len;  //消息的长度
	__u8 *buf;   //消息首地址
  }
  
  int i2c_transfer(struct i2c_adapter *adap,struct
                      i2c_msg *msgs,int num)
功能 ：将封装好的消息发送给总线驱动
参数：
   adap：总线驱动的对象
   msgs：消息首地址
   num：消息个数
返回值：成功返回消息个数，失败 否
封装消息：
    有多少起始位就有多少消息，消息的长度以字节来表示
	（7位从机地址 + 1（写0）)+ 8位寄存器地址+ 8位数据位 (长度为2)
	
	int i2c_write_reg(char reg,char val) //需要写入的寄存器地址 以及val
    {
		int ret;
		char w_buf[] = {reg,val};
	    struct i2c_msg w_msg = {
		   .addr  = client->addr,
		   .flags = 0,
		   .len   = 2,
		   .buf   = w_buf,
		}
	
	   ret = i2c_transfer(client->adapter,&w_msg,1);//成功返回消息个数
	   if(ret != 1)
	   {
	      printk("i2c write error\n");
		  return -EAGAIN;
	   }
	   return 0;
	}
	
	（7位从机地址 + 1（写0）) + 8位寄存器地址
		+（7位从机地址 + 1（读1）)+  从机给主机发送8位数据位
		
   int i2c_read_reg(char reg) //返回值是读取寄存器的值
    {
		int ret;
		char val;
		char r_buf [] = {reg};
		char w_buf[] = {reg,val};
	    struct i2c_msg r_msg []= {
		  [0] = {
		   .addr  = client->addr,
		   .flags = 0,
		   .len   = 1,
		   .buf   = r_buf,
		   },
		  [1] = {
		   .addr  = client->addr,
		   .flags = 1,
		   .len   = 1,
		   .buf   = &val, //读取到的值
		   }，
		}；
	
	   ret = i2c_transfer(client->adapter,r_msg,2);//成功返回消息个数
	   if(ret != 2)
	   {
	      printk("i2c read reg error\n");
		  return -EAGAIN;
	   }
	   return val;
	}
    
  
  ```

==主机向从机写数据

>1.主机首先产生START信号
>2.然后紧跟着发送一个从机地址，这个地址共有7位，紧接着的第8位是数据方 向位(R/W)，0表示主机发送数据(写)，1表示主机接收数据(读)
>3.主机发送地址时，总线上的每个从机都将这7位地址码与自己的地址进行比较，若相同，则认为自己正在被主机寻址，根据R/T位将自己确定为发送器和接收器
   这时候主机等待从机的应答信号(A)
>4.当主机收到应答信号时，发送要访问从机的那个地址， 继续等待从机的应答信号
>5.当主机收到应答信号时，发送N个字节的数据，继续等待从机的N次应答信号，
>6.主机产生停止信号，结束传送过程。

==主机向从机读数据==

>1.主机首先产生START信号
>2.然后紧跟着发送一个从机地址，注意此时该地址的第8位为0，表明是向从机写命令，
>3.这时候主机等待从机的应答信号(ACK)
>4.当主机收到应答信号时，发送要访问的地址，继续等待从机的应答信号，
>5.当主机收到应答信号后，主机要改变通信模式(主机将由发送变为接收，从机将由接收变为发送)所以主机重新发送一个开始start信号，然后紧跟着发送一个从机地址，注意此时该地址的第8位为1，表明将主机设 置成接收模式开始读取数据，
>这时候主机等待从机的应答信号，当主机收到应答信号时，就可以接收1个字节的数据，当接收完成后，主机发送非应答信号，表示不在接收数据
>6.主机进而产生停止信号，结束传送过程。

读数据方向时，主机会释放对 SDA 信号线的控制，由从机控制 SDA 信号线，主机接收信号，
写数据方向时， SDA 由主机控制，从机接收信号(谁写数据 谁可以控制sda线)
读数据的时候需要进行两次寻址，第一次寻址为从机地址，第二次寻址为寄存器地址

==i2c不通原因？

[SOLUTION]
I2C不通，有两种原因，一种是device端（也就是我们的camera sensor）本身就没有回ACK，另一中就是在master端（也就是我们的baseband端），如果我们的，master端就本身异常。那么I2C不通就不足为奇了
我们可以从kernel log里面搜索I2C的关键字，无非是“I2C_TIMEOUT”和“I2C_ACKERR”。。
如果您搜索到了I2C_ACKERR，那么问题多半在slave端，您需要检查您的上电时需是否符合sensor spec的规范，和模组厂的工程师或者sensor厂的工程师一起修改sensor的上电时序，
如果您搜索到的是I2C_TIMEOUT，那么问题多半在master端，
出现I2C_TIMEOUT的rootcause之一是，在I2C bus上没有电的情况下去操作I2C，就会出现timeout
一般来说，我们正常的follow：  Camera Power On --> Write/Read I2C ---> Camera Power Off
在下面的follow下，就会有I2C timeout： Camera Power Off --> Write/Read I2C
我们根据上述条件，通过代码和log去跟踪camera  power on/off和write/read I2C的follow，找出异常点，那么这个问题就迎刃而解

上电不正确，地址不对，速率太高也不行，其它外设占用电没释放，其它外设拉住了sda，机器，芯片，i2c总线配置，硬件等问题。
I2C不通排查流程
逻辑分析仪/示波器测量SCL/SDA波形
检查HW部分：
检查GPIO配置是否正确
以及上拉电阻是否有正确连接
以上如果检查无误，确认是否有slave拉住信号线
SW部分：
检查bus number是否正确
以上检查完成，预计应有波形输出，进一步确认以下波形内容
确认抓取到的地址是否正确
确认是否有ACK，若到此处仍无ACK需由slave vendor分析

P.S I2C timeraout的root cause有很多，但是在I2C bus上没有电的情况下去操作I2C是最常见的
i2c速率正常400k，有的芯片不支持速率太大。


