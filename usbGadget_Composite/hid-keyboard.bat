set ip_addr=10.10.94.102
set printer_path=D:\work\project\printer\printer_test
set hid_dev=/dev/hidg0
adb disconnect %ip_addr%
rem adb -s 0123456789ABCDEF tcpip 5555
adb connect %ip_addr%
adb -s %ip_addr% root
adb -s %ip_addr% remount
adb -s %ip_addr% push %printer_path%\hid /data/hid
adb -s %ip_addr% shell "chmod 755 /data/hid"
adb -s %ip_addr% shell "./data/hid %hid_dev% keyboard"
pause