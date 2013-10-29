/*
  spike.c
  Copyright Scott Ellis, 2010
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.
  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
  spike v0.1 loads and registers a spi driver for a device at the bus/
  cable select specified by the constants SPI_BUS.SPI_BUS_CS1
*/

// How to test the driver
//
// 1. scp to RPI
// 2. run ./load.sh on RPI
//    2.1. doesn't work?
//    2.2. run ./load.sh again
// 3. run ./test.sh
// TODO: Investigate why do we need to reload the driver???



// Todo:
// 1. Add support for reading only part of the output from the FPGA, right the same data is read the second time read is called even thou that data has already been read.
// 2.

// To remove "ISO C90 forbids mixed declarations and code [-Wdeclaration-after-statement]" warning
#pragma GCC diagnostic ignored "-Wdeclaration-after-statement"

#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/device.h>
//#include <linux/mutex.h>
//#include <linux/slab.h>
#include <linux/cdev.h>
#include <linux/spi/spi.h>
#include <linux/string.h>
#include <asm/uaccess.h>

#define LOG(type, msg, ...)                                             \
  do {                                                                  \
    printk("\033[34m%s\033[0m: %4d : %s: ", __FILE__, __LINE__, type); \
    printk(msg, ##__VA_ARGS__);                                       \
    printk("\n");                                                     \
  } while(0)

#define LOG_ERROR(msg, ...) LOG("\033[31;1mERROR   \033[0m", msg, ##__VA_ARGS__)
#define LOG_WARNING(msg, ...) LOG("\033[33mWARNING \033[0m", msg, ##__VA_ARGS__)
#define LOG_DEBUG(msg, ...) LOG("\033[32mNOTE    \033[0m", msg, ##__VA_ARGS__)

// set to 1 to enable function call trace
#if 1
  #define LOG_ENTRY() LOG("\033[37;1mENTRY   ", "%s%s", __func__, "\033[0m")
  #define LOG_EXIT() LOG("\033[37;1mEXIT    ", "%s%s", __func__, "\033[0m")
#else
  #define LOG_ENTRY() ;
  #define LOG_EXIT() ;
#endif


#define USER_BUFF_SIZE 128

#define SPI_BUS 0
#define SPI_BUS_CS 0
#define SPI_BUS_SPEED 1000


// Driver name that should match the name of the struct spi_board_info
// in the arcitecture file when building the linux kernel.
const char this_driver_name[] = "spidev"; // Should be slot car...


struct spike_dev {
  // TODO: Check if these semaphores are actually needed
  //struct semaphore spi_sem;
  //struct semaphore fop_sem;

  // This struct holds the device numbers (major and minor)
  dev_t devt;

  //
  struct cdev cdev;

  //
  struct class *class;

  //
  struct spi_device *spi_device;

  // Buffer used to store data between write and read
  char *user_buff;

  // The length of the buffer
  size_t len;
};

static struct spike_dev spike_dev;

static ssize_t fop_slotcar_write(struct file *filp, const char *buff, size_t len, loff_t *off)
{
  LOG_ENTRY();
  if(spike_dev.spi_device == NULL) {
      LOG_ERROR("spike_dev is null");
      return 0;
  }
  char data_to_write[USER_BUFF_SIZE];

  // TODO: Remove -1 when null-terminatino is no longer needed
  len = min(len, USER_BUFF_SIZE - 1);

  
  if (copy_from_user(data_to_write,buff, len) < 0) {
    LOG_ERROR("Copy from user failed");
    return 0;
  }

  // TODO: Remove this when no longer needed
  data_to_write[len] = '\0';

  LOG_DEBUG("Sending: %s %d\r", data_to_write, len);

  int i;
  for (i = 0; i <= len; i++) {
    size_t res = spi_w8r8(spike_dev.spi_device, data_to_write[i]);
    spike_dev.user_buff[i] = res;
    printk("S='%c', R='%c' %x\n", data_to_write[i], res, res);
  }
  spike_dev.len = len;

  LOG_EXIT();
  return 0;
}

static ssize_t fop_slotcar_read(struct file *filp, char __user *buff, size_t count,
			  loff_t *offp)
{
  LOG_ENTRY();

  if (!buff) {
    LOG_ERROR("User buffer is null");
    return -EFAULT;
  }

  // TODO: Why is this check needed?
  if (*offp > 0) {
    LOG_ERROR("Offset... something wrong... or is there?");
    return 0;
  }

  //if (down_interruptible(&spike_dev.fop_sem))
  //  return -ERESTARTSYS;

  if (!spike_dev.spi_device) {
    LOG_ERROR("spike_dev is null");
    //strcpy(spike_dev.user_buff, "spi_device is NULL\n");
    return 0;
  }
  else if (!spike_dev.spi_device->master) {
    LOG_ERROR("spike_device->master is null");
    //strcpy(spike_dev.user_buff, "spi_device->master is NULL\n");
    return 0;
  }

  LOG_DEBUG("%s is ready on SPI%d.%d",
	    this_driver_name,
	    spike_dev.spi_device->master->bus_num,
	    spike_dev.spi_device->chip_select);

  LOG_DEBUG("spike_dev.len = %d, count=%d", spike_dev.len, count);

  // TODO: Why is this needed, why isn't this set correctly in write
  spike_dev.len = 4;
 
  // only read as much as is available and not more
  count = min(spike_dev.len, count);

  ssize_t status = 0;
  if (copy_to_user(buff, spike_dev.user_buff, count)) {
    LOG_ERROR("copy_to_user() failed");
    status = -EFAULT;
  }
  else {
    *offp += count;
    // A fops read should return the number of bytes read if it succeeds
    status = count;
  }

  //up(&spike_dev.fop_sem);

  LOG_EXIT();
  return status;	
}

/**Called when /dev/spidev is opened
 *
 */
static int fop_slotcar_open(struct inode *inode, struct file *filp)
{
  LOG_ENTRY();
  int status = 0;

  //if (down_interruptible(&spike_dev.fop_sem))
  //  return -ERESTARTSYS;

  // first time opened?
  if (!spike_dev.user_buff) {
    spike_dev.user_buff = kmalloc(USER_BUFF_SIZE, GFP_KERNEL);

    if (!spike_dev.user_buff) {
      LOG_ERROR("Failed to allocate memory for userbuff");
      status = -ENOMEM;
    }
  }	

  //up(&spike_dev.fop_sem);

  LOG_EXIT();
  return status;
}


























/** Called either during boot or when device is connected ????
 *
 * TODO: Add support for handling hotswapable spi device
 *
 * TODO: Why is this called twice during load??
 */
static int dev_slotcar_probe(struct spi_device *spi_device)
{
  LOG_ENTRY();
  //  if (down_interruptible(&spike_dev.spi_sem))
  //  return -EBUSY;

  spike_dev.spi_device = spi_device;

  //up(&spike_dev.spi_sem);

  LOG_EXIT();
  return 0;
}

/** Called when the device driver is removed (rmmod)
 *
 * TODO: Add cleanup.. it seems like there is something missing when removing the driver
 *
 */
static int __devexit dev_slotcar_remove(struct spi_device *spi_device)
{
  LOG_ENTRY();
  //if (down_interruptible(&spike_dev.spi_sem))
  //  return -EBUSY;

  // TODO: Free the memory before clearing pointer
  spike_dev.spi_device = NULL;

  //up(&spike_dev.spi_sem);

  LOG_EXIT();
  return 0;
}

static int __init add_spike_device_to_bus(void)
{
  LOG_ENTRY();
  struct spi_master *spi_master;
  struct spi_device *spi_device;
  struct device *pdev;
  char buff[64];
  int status = 0;

  spi_master = spi_busnum_to_master(SPI_BUS);

  if (!spi_master) {
    LOG_ERROR("spi_busnum_to_master(%d) returned NULL", SPI_BUS);
    LOG_ERROR("Missing modprobe omap2_mcspi?");
    return -1;
  }

  spi_device = spi_alloc_device(spi_master);
  if (!spi_device) {
    put_device(&spi_master->dev);
    LOG_ERROR("spi_alloc_device() failed");
    return -1;
  }

  spi_device->chip_select = SPI_BUS_CS;

  /* Check whether this SPI bus.cs is already claimed */
  snprintf(buff, sizeof(buff), "%s.%u", dev_name(&spi_device->master->dev), spi_device->chip_select);

  pdev = bus_find_device_by_name(spi_device->dev.bus, NULL, buff);
  if (pdev) {
    /* We are not going to use this spi_device, so free it */
    spi_dev_put(spi_device);

    /*
     * There is already a device configured for this bus.cs
     * It is okay if it us, otherwise complain and fail.
     */
    if (pdev->driver && pdev->driver->name && strcmp(this_driver_name, pdev->driver->name)) {
      LOG_ERROR("Driver [%s] already registered for %s", pdev->driver->name, buff);
      status = -1;
    }
  }
  else {
    spi_device->max_speed_hz = SPI_BUS_SPEED;
    spi_device->mode = SPI_MODE_0;
    spi_device->bits_per_word = 8;
    spi_device->irq = -1;
    spi_device->controller_state = NULL;
    spi_device->controller_data = NULL;
    strlcpy(spi_device->modalias, this_driver_name, SPI_NAME_SIZE);

    status = spi_add_device(spi_device);
    if (status < 0) {	
      spi_dev_put(spi_device);
      LOG_ERROR("spi_add_device() failed: %d", status);	
    }	
  }

  put_device(&spi_master->dev);

  LOG_EXIT();
  return status;
}

static struct spi_driver spike_driver = {
  .driver = {
    // Needs to match the one specified in the linux kernel architecture...
    // Otherwise probe is not run correctly
    .name  = this_driver_name,
    .owner = THIS_MODULE,
  },
  .probe = dev_slotcar_probe,

  /** 
   * __devexit
   *     Functions marked as __devexit may be discarded at kernel link time, depending
   *     on config options.  Newer versions of binutils detect references from
   *     retained sections to discarded sections and flag an error.  Pointers to
   *     __devexit functions must use __devexit_p(function_name), the wrapper will
   *     insert either the function_name or NULL, depending on the config options.
   */
  .remove = __devexit_p(dev_slotcar_remove),
};

/**
 * __init
 *     The __init macro causes the init function to be discarded and its memory freed
 *     once the init function finishes for built-in drivers, but not loadable modules.
 *     If you think about when the init function is invoked, this makes perfect sense.
 */

static int __init dev_slotcar_init_spi(void)
{
  LOG_ENTRY();
  int error;

  error = spi_register_driver(&spike_driver);
  if (error < 0) {
    LOG_ERROR("spi_register_driver() failed %d", error);
    return error;
  }

  error = add_spike_device_to_bus();
  if (error < 0) {
    LOG_ERROR("add_spike_to_bus() failed");
    spi_unregister_driver(&spike_driver);
    return error;
  }

  LOG_EXIT();
  return 0;
}

static const struct file_operations fops_slotcar = {
  .owner = THIS_MODULE,
  .read  = fop_slotcar_read,
  .write = fop_slotcar_write,
  .open  = fop_slotcar_open,
};

static int __init dev_slotcar_init_cdev(void)
{
  LOG_ENTRY();
  int error;

  spike_dev.devt = MKDEV(0, 0);

  error = alloc_chrdev_region(&spike_dev.devt, 0, 1, this_driver_name);
  if (error < 0) {
    LOG_ERROR("alloc_chrdev_region() failed: %d", error);
    return -1;
  }

  cdev_init(&spike_dev.cdev, &fops_slotcar);
  spike_dev.cdev.owner = THIS_MODULE;

  error = cdev_add(&spike_dev.cdev, spike_dev.devt, 1);
  if (error) {
    LOG_ERROR("cdev_add() failed: %d", error);
    unregister_chrdev_region(spike_dev.devt, 1);
    return -1;
  }	

  LOG_EXIT();
  return 0;
}

static int __init dev_slotcar_init_class(void)
{
  LOG_ENTRY();
  spike_dev.class = class_create(THIS_MODULE, this_driver_name);

  if (!spike_dev.class) {
    LOG_ERROR("class_create() failed");
    return -1;
  }

  if (!device_create(spike_dev.class, NULL, spike_dev.devt, NULL,
		     this_driver_name)) {
    LOG_ERROR("device_create(..., %s) failed", this_driver_name);
    class_destroy(spike_dev.class);
    return -1;
  }

  LOG_EXIT();
  return 0;
}

/** Is called when the driver is loaded
 *
 */
static int __init dev_slotcar_init(void)
{
  LOG_ENTRY();
  memset(&spike_dev, 0, sizeof(spike_dev));

  //sema_init(&spike_dev.spi_sem, 1);
  //sema_init(&spike_dev.fop_sem, 1);

  // Inits...
  if (dev_slotcar_init_cdev() < 0)
    goto fail_1;

  // Inits..
  if (dev_slotcar_init_class() < 0)
    goto fail_2;

  // Inits...
  if (dev_slotcar_init_spi() < 0)
    goto fail_3;

  LOG_EXIT();
  return 0;

 fail_3:
  device_destroy(spike_dev.class, spike_dev.devt);
  class_destroy(spike_dev.class);

 fail_2:
  cdev_del(&spike_dev.cdev);
  unregister_chrdev_region(spike_dev.devt, 1);

 fail_1:
  return -1;
}

/**
 * __exit
 *     This macro excludes the function if built into the kernel
 *     For loadable modules it does nothing.
 */
static void __exit dev_slotcar_exit(void)
{
  LOG_ENTRY();
  /* If you're hotplugging an adapter with devices (parport, usb, etc)
   * use spi_new_device() to describe each device.  You can also call
   * spi_unregister_device() to start making that device vanish, but
   * normally that would be handled by spi_unregister_master().
   *
   * You can also use spi_alloc_device() and spi_add_device() to use a two
   * stage registration sequence for each spi_device.  This gives the caller
   * some more control over the spi_device structure before it is registered,
   * but requires that caller to initialize fields that would otherwise
   * be defined using the board info.
   */
  spi_unregister_device(spike_dev.spi_device);
  // Reverse effect of spi_register_driver
  spi_unregister_driver(&spike_driver);

  // This call unregisters and cleans up a device that was created with a call to device_create().
  device_destroy(spike_dev.class, spike_dev.devt);

  // Destroys a struct class structure, the pointer to be destroyed must have been created with a call to class_create()
  class_destroy(spike_dev.class);

  // Remove a cdev from the system, possibly freeing the structure
  cdev_del(&spike_dev.cdev);

  // This function will unregister a range of @count device numbers
  unregister_chrdev_region(spike_dev.devt, 1);

  if (spike_dev.user_buff) {
    kfree(spike_dev.user_buff);
  }
  LOG_EXIT();
}



// Registers function to be run at kernel boot time or module insertion
module_init(dev_slotcar_init);

// Registers function to be run when driver is removed
module_exit(dev_slotcar_exit);


MODULE_AUTHOR("Scott Ellis");
MODULE_DESCRIPTION("spike module - an example SPI driver");
MODULE_LICENSE("GPL");
MODULE_VERSION("0.1");
