
 [[MTK]]

## ##DDR定档指令

在排查DDR的问题时，客户做一些实验或者测试时，需要fix DDR档位，客户可能会需要知道：
如何fix最高档，固定某个档位？
如何解除fix档位的状态？

以mt6878为例：
先通过下文表格中get opp table命令获取支持的档位：

![[ddr-1.png]]

然后通过下文表格中set fixed mode设定到想要的档位，比如最低档，然后再通过get current opp查看是否设定成功：
![[ddr-2.png]]

最后可通过release force mode解除force mode状态：
![[ddr-3.png]]

**各平台DDR相关命令**

|   |   |   |
|---|---|---|
|**Chip No.**|**Requirements**|**CMDs**|
|MT6761|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6761|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6761|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6761|release force mode|adb shell "echo 16 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6765|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6765|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6765|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6765|release force mode|N/A|
|MT6768/MT6769|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6768/MT6769|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6768/MT6769|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6768/MT6769|release force mode|adb shell "echo 16 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6781|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6781|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6781|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6781|release force mode|adb shell "echo 13 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6789|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6789|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6789|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6789|release force mode|adb shell "echo 21 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6789B|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6789B|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6789B|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6789B|release force mode|adb shell "echo 21 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6833|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6833|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6833|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6833|release force mode|adb shell "echo 25 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6835|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6835|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6835|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6835|release force mode|adb shell "echo 21 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6853|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6853|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6853|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6853|release force mode|adb shell "echo 21 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6855|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6855|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6855|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6855|release force mode|adb shell "echo 33 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6858|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6858|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6858|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6858|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6877|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6877|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6877|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6877|release force mode|adb shell "echo 32 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6878|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6878|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6878|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6878|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6879|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6879|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6879|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6879|release force mode|adb shell "echo 33 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6881|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6881|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6881|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6881|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6886|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6886|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6886|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6886|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6893|get opp table (supported freqs)|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_opp_table"|
|MT6893|get current opp|adb shell "cat /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_dump"|
|MT6893|set fixed mode|adb shell "echo %1 >/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6893|release force mode|adb shell "echo 32 > /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6895|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6895|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6895|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6895|release force mode|adb shell "echo 32 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6897|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6897|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6897|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6897|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6899|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6899|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6899|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6899|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6983|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6983|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6983|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6983|release force mode|adb shell "echo 32 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6985|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6985|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6985|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6985|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6989|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6989|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6989|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6989|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6991|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6991|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6991|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6991|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6993|get opp table (supported freqs)|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_opp_table"|
|MT6993|get current opp|adb shell "cat /sys/kernel/helio-dvfsrc/dvfsrc_dump"|
|MT6993|set fixed mode|adb shell "echo %1 >/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|
|MT6993|release force mode|adb shell "echo 255 > /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp"|


[](https://online.mediatek.com/apps/search/filter?keyword=&start=0&app=FAQ)[adb](https://online.mediatek.com/apps/search/filter?keyword=adb&start=0&app=FAQ)[DDR定档](https://online.mediatek.com/apps/search/filter?keyword=DDR%E5%AE%9A%E6%A1%A3&start=0&app=FAQ)[DDR定最高档/最低档](https://online.mediatek.com/apps/search/filter?keyword=DDR%E5%AE%9A%E6%9C%80%E9%AB%98%E6%A1%A3%2F%E6%9C%80%E4%BD%8E%E6%A1%A3&start=0&app=FAQ)

# DDR兼容数量限制 

[DESCRIPTION]

MTK平台对于DDR兼容数量会有限制，上限一般按经验会设成10颗或30颗。

之所以有限制，是因为preloader是放在基带芯片的SRAM上执行，而SRAM SIZE是非常有限的。

所以各个模块都会尽量减少preloader size占用。DDR如果兼容数量太多，可能会让preloader size爆掉。

[SOLUTION]

在确保preloader size没有爆掉的前提下，如果要增加DDR兼容上限，可以参考如下内容。

1.  修改emigen文件

     vendor/mediatek/proprietary/bootable/bootloader/preloader / tools/emigen/common/emigen_vx.pm：  
     die "\n[Error]CustCS_CustemChips($CustCS_CustemChips) > 40\n" if ($CustCS_CustemChips > 40);    //默认一般是30；

2.  修改emigen文件之后，然后添加DDR兼容物料：

     2.1  如果能正常编译和下载，表示没有问题；

     2.2  如果preloader size爆掉，会有build error出现，那么没有办法增加DDR物料数量；

     2.3  如果build pass，但是download fail。请提交CR并附上download log，请鄙司Flashtool/DA同仁检查是否是Tool或DA有限制；

#  兼容DDR物料build 

[DESCRIPTION]

兼容新的DDR物料，可能会遇到如下编译报错：

DRAM[Error] LPDDR4 MODE_REG5+DRAM_RANKx_SIZE should not be the same in the Combo list, MODE_REG5+DRAM_RANKx_SIZE(BWMECX32H2A_08G_X)==DRAM_RANKx_SIZE(NCLDXC1MG256M32)

[SOLUTION]

上述报错，实际上表示有两颗DDR物料的Vendor ID & RANK SIZE完全一致。

这种情况，一般只会出现在两颗DSC/离散物料之间。

因为MCP物料，会通过**MCP ID** & Vendor ID & RANK SIZE来区分，其中**MCP ID**一般都是唯一的，不会跟其他物料相同。

而DSC/离散物料, 是通过Vendor ID & RANK SIZE来区分，Vendor ID & RANK SIZE有可能会完全相同。

如果两颗DSC DDR物料的Vendor ID & RANK SIZE完全相同，编译就会报错。

解决方法：

这种情况下，可以拿掉其中一颗DDR。即：在custom_MemoryDevice.h & MDL中只需要填写一个物料的参数即可。

因为只要添加一颗物料的参数，两颗DSC物料就可以被识别到。

# eMMC和DDR的工作clk确认

[DESCRIPTION]

 查看eMMC和DDR的工作频率

[SOLUTION]

 eMMC：

     adb shell cat /sys/kernel/debug/mmc0/clock

 DDR：

     adb shell cat /sys/bus/platform/drivers/emi_clk_test/read_dram_data_rate