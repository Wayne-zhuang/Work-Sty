编译printer方法：
armv7a-linux-androideabi30-clang printer_new.c -o printer  -Wno-implicit-function-declaration -std=c11
编译HID方法：
armv7a-linux-androideabi30-clang hid_test.c -o hid -Wno-implicit-function-declaration -std=c11