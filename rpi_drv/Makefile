#Makefile start

TEST=sed -e "s/\(\/[^:]*\)/`echo '\033[34;1m\\\\1\033[0m'`/g"  -e "s/\(:[0-9]*:[0-9]*:\)/`echo '\033[37m\\\\1\033[0m'`/g" -e "s/\(error\)/`echo '\033[31;1m\\\\1\033[0m'`/g" -e "s/\(note\)/`echo '\033[32;1m\\\\1\033[0m'`/g" -e "s/\(warning\)/`echo '\033[35m\\\\1\033[0m'`/g" -e "s/\(\‘[^\’]*\’\)/`echo '\033[38;1m\\\\1\033[0m'`/g"

obj-m := sc_dev.o
sc_dev-objs := sc_drv.o fop.o log.o

#KVERSION = $(shell uname -r)
all:
	make -C $(INSTALL_MOD_PATH)/lib/modules/3.6.11+/build M=$(PWD) modules 2>&1 | ${TEST}
	echo $(INSTALL_MOD_PATH)
clean:
	make -C $(INSTALL_MOD_PATH)/lib/modules/3.6.11+/build M=$(PWD) clean

install: all
	scp sc_drv.ko rpi@192.168.100.10:/home/rpi
#	ssh rpi@192.168.100.10 'sudo ./home/rpi/load.sh'

#Makefile end

