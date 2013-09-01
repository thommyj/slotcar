#Makefile start

obj-m := sc_drv.o
#KVERSION = $(shell uname -r)
all:
	make -C $(INSTALL_MOD_PATH)/lib/modules/3.6.11+/build M=$(PWD) modules
clean:
	make -C $(INSTALL_MOD_PATH)/lib/modules/3.6.11+/build M=$(PWD) clean

#Makefile end
