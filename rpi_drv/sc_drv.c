// How to test the driver
//
// 1. scp to RPI
// 2. run ./load.sh on RPI
// 3. run ./test.sh

//
// TODO
// 1. XXX
//

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <asm/uaccess.h>

#include "log.h"

/*
 *  Prototypes - this would normally go in a .h file
 */
static int __init dev_slotcar_init(void);
static int __init dev_slotcar_init_cdev(driver_data_t *data);
static int __init dev_slotcar_init_class(void);
static int __init dev_slotcar_init_spi(void);
static int __init dev_slotcar_add_device_to_bus(void);
static void __exit dev_slotcar_exit(void);

static ssize_t fop_slotcar_write(struct file *filp, const char *buff, size_t len, loff_t *offp);
static ssize_t fop_slotcar_read(struct file *filp, char __user *buff, size_t count, loff_t *offp);
static int fop_slotcar_open(struct inode *inode, struct file *filp);

static int dev_slotcar_probe(struct spi_device *spi_dev);
static int __devexit dev_slotcar_remove(struct spi_device *spi_dev);

/*
 * Global variables are declared as static, so are global within the file. 
 */
static driver_data_t driver_data;

/**
 * file operations struct
 */
static const struct file_operations fops_slotcar = {
  .owner = THIS_MODULE,
  .read  = fop_slotcar_read,
  .write = fop_slotcar_write,
  .open  = fop_slotcar_open,
};

/**
 * spi driver struct
 */
static struct spi_driver slotcar_driver = {
  .driver = {
    .name  = driver_name,
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
 * Checks so that the driver has been properly initiated and makes sure you
 * dont try to access memory ouside of the FPGAs memory boundary
 */
static int check_values(driver_data_t *data, loff_t *offp)
{
  if (*offp > FPGA_MEMORY_SIZE) {
    LOG_WARNING("End of memory reached, discarding rest of data");
    return -1;
  }

  if(data == NULL) {
    LOG_ERROR("driver_data is null");
    return -1;
  }
  else if(data->spi_device == NULL) {
    LOG_ERROR("spi_device is null");
    return -1;
  }
  else if (!data->spi_device->master) {
    LOG_ERROR("spi_device->master is null");
    return -1;
  }
  return 0;
}

/**
 * Sends a command to the FPGA
 *
 * TODO: refactor, two functions?
 */
static int spi_send_command(spi_device_t *spi_device, char command, char address, char value, char *result)
{
  size_t res = spi_w8r8(spi_device, command | (address & SPI_ADDRESS_MASK));

  if(res < 0) {
    LOG_ERROR("spi_w8r8 failed to send command");
    return -1;
  }
  else if(res != SPI_TRANSFER_CODE_OK) {
    LOG_ERROR("FPGA did not respond with %x when sending command, got %x", SPI_TRANSFER_CODE_OK, res);
    return -1;
  }
  res = spi_w8r8(spi_device, value);

  if(res < 0) {
    LOG_ERROR("spi_w8r8 failed to send value");
    return -1;
  }
  else if(res != SPI_TRANSFER_CODE_OK) {
    LOG_ERROR("FPGA did not respond with %x when sending address, got %x", SPI_TRANSFER_CODE_OK, res);
    return -1;
  }
  *result = res;
  return 0;
}

/**
 * Writes one byte at a time at the addres specified by offp
 *
 * TODO: fix so that you are able to write to the whole memory at once
 */
static ssize_t fop_slotcar_write(struct file *filp, const char *buff, size_t len, loff_t *offp)
{
  LOG_ENTRY();
  driver_data_t *data = (driver_data_t *) filp->private_data;

  LOG_DEBUG("User wants to write %i bytes at memory location %lld", len, *offp);

  if(check_values(data, offp) < 0) {
    LOG_EXIT();
    return len;
  }

  // only write one byt at a time
  ssize_t send_len = min(len, (size_t)1);

  char data_to_write;
  char result;

  if (copy_from_user(&data_to_write, buff, send_len)) {
    LOG_ERROR("Copy from user failed");
    LOG_EXIT();
    return len;
  }

  LOG_DEBUG("Writing: %c on memory address %lld", data_to_write, *offp);
  if(spi_send_command(data->spi_device, SPI_WRITE | SPI_INTERNAL, *offp, data_to_write, &result) < 0) {
    LOG_ERROR("Failed to send command");
    LOG_EXIT();
    return len;
  }

  //TODO unclear if this should be here or not, but otherwise the offset will not increase...
  *offp += send_len;

  LOG_EXIT();
  return send_len;
}

/**
 * Reads one byte at a time at the addres specified by offp
 *
 * TODO: fix so that you are able to read the whole memory at once
 */
static ssize_t fop_slotcar_read(struct file *filp, char __user *buff, size_t count, loff_t *offp)
{
  LOG_ENTRY();
  driver_data_t *data = (driver_data_t *) filp->private_data;

  LOG_DEBUG("User wants to read %i bytes at memory location %lld", count, *offp);

  if(check_values(data, offp) < 0) {
    LOG_EXIT();
    return 0;
  }

  //TODO fix so that you can read the whole memory at once...
  //  read_len = min(count, FPGA_MEMORY_SIZE);
  ssize_t read_len = min(count, (size_t)1);

  char data_read;
  if(spi_send_command(data->spi_device, SPI_READ | SPI_INTERNAL, *offp, SPI_TRANSFER_WAIT_FOR_READ, &data_read) < 0) {
    LOG_ERROR("Failed to read data");
    LOG_EXIT();
    return 0;
  }
  LOG_DEBUG("Read: %c on memory address %lld", data_read, *offp);

  if (copy_to_user(buff, &data_read, read_len)) {
    LOG_ERROR("copy_to_user() failed");
    LOG_EXIT();
    return -EFAULT;
  }
  //TODO unclear if this should be here or not, but otherwise the offset will not increase...
  *offp += read_len;

  LOG_EXIT();
  return read_len;
}

/**
 * Called when /dev/spidev is opened
 *
 */
static int fop_slotcar_open(struct inode *inode, struct file *filp)
{
  LOG_ENTRY();

  // neccessary?
  driver_data_t *data = container_of(inode->i_cdev, driver_data_t, cdev);
  filp->private_data = data;

  int status = 0;

  LOG_EXIT();
  return status;
}

/**
 * Called either during boot or when device is loaded
 *
 * TODO: Add support for handling hotswapable spi device
 */
static int probe_cnt=0; // TODO: only temporary, should be removed
static int dev_slotcar_probe(struct spi_device *spi_dev)
{
  LOG_ENTRY();

  if(probe_cnt == 0)
    driver_data.spi_device = spi_dev;
  else
    driver_data.spi_device2 = spi_dev;

  probe_cnt++;

  print_spi_device_info(spi_dev);

  LOG_EXIT();
  return 0;
}

/**
 * Called when the device driver is removed (rmmod)
 */
static int __devexit dev_slotcar_remove(struct spi_device *spi_dev)
{
  LOG_ENTRY();
  print_spi_device_info(spi_dev);

  driver_data.spi_device = NULL;

  LOG_EXIT();
  return 0;
}

/**
 * Is called when the driver is loaded
 */
static int __init dev_slotcar_init(void)
{
  LOG_ENTRY();

  memset(&driver_data, 0, sizeof(driver_data));

  if (dev_slotcar_init_cdev(&driver_data) >= 0) {
    if (dev_slotcar_init_class() >= 0) {
      if (dev_slotcar_init_spi() >= 0) {
        LOG_DEBUG("Init driver ok");
        LOG_EXIT();
        return 0;
      }
      device_destroy(driver_data.class, driver_data.devt);
      class_destroy(driver_data.class);
    }
    cdev_del(&driver_data.cdev);
    unregister_chrdev_region(driver_data.devt, 1);
  }
  LOG_ERROR("Initialization of driver failed");
  LOG_EXIT();
  return -1;
}

/**
 * Initializes the character device and gets the major and minor number
 */
static int __init dev_slotcar_init_cdev(driver_data_t *data)
{
  LOG_ENTRY();
  int error;
  int count = 1;

  dev_t devt = MKDEV(0, 0);

  // Ask the kernel for a major/minor number
  error = alloc_chrdev_region(&devt, 0, count, driver_name);
  if (error < 0) {
    LOG_ERROR("alloc_chrdev_region() failed: %d", error);
    return -1;
  }

  cdev_init(&data->cdev, &fops_slotcar);
  data->cdev.owner = THIS_MODULE;

  error = cdev_add(&data->cdev, devt, count);
  if (error < 0) {
    LOG_ERROR("cdev_add() failed: %d", error);
    unregister_chrdev_region(devt, count);
    return -1;
  }

  data->devt = devt;

  LOG_EXIT();
  return 0;
}

/**
 * Creates a class for the driver
 *
 * TODO: investigate if it is needed, probably remove
 */
static int __init dev_slotcar_init_class(void)
{
  LOG_ENTRY();
  driver_data.class = class_create(THIS_MODULE, driver_name);

  if (!driver_data.class) {
    LOG_ERROR("class_create() failed");
    return -1;
  }

  if (!device_create(driver_data.class, NULL, driver_data.devt, NULL, driver_name)) {
    LOG_ERROR("device_create(..., %s) failed", driver_name);
    class_destroy(driver_data.class);
    return -1;
  }

  LOG_EXIT();
  return 0;
}

/**
 * Initializes the spi driver
 *
 * __init
 *     The __init macro causes the init function to be discarded and its memory freed
 *     once the init function finishes for built-in drivers, but not loadable modules.
 *     If you think about when the init function is invoked, this makes perfect sense.
 */
static int __init dev_slotcar_init_spi(void)
{
  LOG_ENTRY();
  int error;

  error = spi_register_driver(&slotcar_driver);
  if (error < 0) {
    LOG_ERROR("spi_register_driver() failed %d", error);
    return error;
  }

  error = dev_slotcar_add_device_to_bus();
  if (error < 0) {
    LOG_ERROR("add_slotcar_to_bus() failed");
    spi_unregister_driver(&slotcar_driver);
    return error;
  }

  LOG_EXIT();
  return 0;
}

/**
 * Adds our driver to the spi master bus
 */
static int __init dev_slotcar_add_device_to_bus(void)
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
    if (pdev->driver && pdev->driver->name && strcmp(driver_name, pdev->driver->name)) {
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
    strlcpy(spi_device->modalias, driver_name, SPI_NAME_SIZE);

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

/**
 * Cleans up the drivers resources when the driver is removed
 *
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
  //LOG_DEBUG("spi_unregister_device");
  //spi_unregister_device(driver_data.spi_device);

  // Reverse effect of spi_register_driver
  spi_unregister_driver(&slotcar_driver);

  // This call unregisters and cleans up a device that was created with a call to device_create().
  device_destroy(driver_data.class, driver_data.devt);

  // Destroys a struct class structure, the pointer to be destroyed must have been created with a call to class_create()
  class_destroy(driver_data.class);

  // Remove a cdev from the system, possibly freeing the structure
  cdev_del(&driver_data.cdev);

  // This function will unregister a range of @count device numbers
  unregister_chrdev_region(driver_data.devt, 1);
  LOG_EXIT();
}

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Erik & Thommy");
MODULE_DESCRIPTION("Driver for slotcar");
MODULE_VERSION("0.1");

//module_spi_driver(spi_test_driver); 

// Registers function to be run at kernel boot time or module insertion
module_init(dev_slotcar_init);
// Registers function to be run when driver is removed
module_exit(dev_slotcar_exit);
