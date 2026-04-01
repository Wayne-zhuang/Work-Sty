set ip_addr=10.10.94.102
set printer_path=D:\work\project\printer\printer_test
adb disconnect %ip_addr%
adb -s 0123456789ABCDEF tcpip 5555
adb connect %ip_addr%
adb -s %ip_addr% root
adb -s %ip_addr% remount
adb -s %ip_addr% push %printer_path%\printer /data/printer
adb -s %ip_addr% shell "chmod 755 /data/printer"
pause
adb -s %ip_addr% shell "setenforce 0"
rem adb -s %ip_addr% shell "echo 10 > /sys/module/musb_hdrc/parameters/debug"
rem adb -s %ip_addr% shell "echo 10 > /sys/module/musb_hdrc/parameters/mtk_qmu_dbg_level"
adb -s %ip_addr% shell "setprop sys.usb.config hid,printer"
adb -s %ip_addr% shell "./data/printer -get_status"
adb -s %ip_addr% shell "./data/printer -read_data"
pause


