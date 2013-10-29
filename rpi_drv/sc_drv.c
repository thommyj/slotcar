/*chardev.c: Creates a read-only char device that says how many times
 *  you've read from the dev file
 */

#define CONFIG_SPI 1

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/spi/spi.h>
#include <asm/uaccess.h>	/* for put_user */

/*  
 *  Prototypes - this would normally go in a .h file
 */
int init_module(void);
void cleanup_module(void);
static int device_open(struct inode *, struct file *);
static int device_release(struct inode *, struct file *);
static ssize_t device_read(struct file *, char *, size_t, loff_t *);
static ssize_t device_write(struct file *, const char *, size_t, loff_t *);

#define SUCCESS 0
#define DEVICE_NAME "slotcar"	/* Dev name as it appears in /proc/devices   */
#define BUF_LEN 80		/* Max length of the message from the device */

/* 
 * Global variables are declared as static, so are global within the file. 
 */

static int Major;		/* Major number assigned to our device driver */
static int Device_Open = 0;	/* Is device open?  
				 * Used to prevent multiple access to device */
static char msg[BUF_LEN];	/* The msg the device will give when asked */
static char *msg_Ptr;

struct slotcar_track {
  struct spi_device *mydev;
} track;

static struct file_operations fops = {
  .owner = THIS_MODULE,
  .read = device_read,
  .write = device_write,
  .open = device_open,
  .release = device_release
};


//
// Called when a device is connected...
//

static int slotcar_probe(struct spi_device *dev)
{
  int ret = 0;
   
  printk("slotcar probe started\n");
  track.mydev = dev;
 
  return ret;
}
 
static int slotcar_remove(struct spi_device *spi)
{
  track.mydev = NULL;
  printk("slotcar removce called\r\n");
  return 0;
}

/*
 * This function is called when the module is loaded
 */
int reg_chdriver(void)
{
  Major = register_chrdev(0, DEVICE_NAME, &fops);

  if (Major < 0) {
    printk(KERN_ALERT "Registering char device failed with %d\n", Major);
    return Major;
  }

  printk(KERN_INFO "I was assigned major number %d. To talk to\n", Major);
  printk(KERN_INFO "the driver, create a dev file with\n");
  printk(KERN_INFO "'mknod /dev/%s c %d 0'.\n", DEVICE_NAME, Major);
  printk(KERN_INFO "Try various minor numbers. Try to cat and echo to\n");
  printk(KERN_INFO "the device file.\n");
  printk(KERN_INFO "Remove the device file and module when done.\n");

  return SUCCESS;
}

/*
 * This function is called when the module is unloaded
 */
void unreg_chdriver(void)
{
  /* 
   * Unregister the device 
   */
  unregister_chrdev(Major, DEVICE_NAME);
}

/*
 * Methods
 */

/* 
 * Called when a process tries to open the device file, like
 * "cat /dev/mycharfile"
 */
static int device_open(struct inode *inode, struct file *file)
{

  static int counter = 0;

  if (Device_Open)
    return -EBUSY;

  Device_Open++;
  sprintf(msg, "I already told you %d times Hello world!\n", counter++);
  msg_Ptr = msg;
  try_module_get(THIS_MODULE);

  return SUCCESS;
}

/* 
 * Called when a process closes the device file.
 */
static int device_release(struct inode *inode, struct file *file)
{
  Device_Open--;		/* We're now ready for our next caller */

  /* 
   * Decrement the usage count, or else once you opened the file, you'll
   * never get get rid of the module. 
   */
  module_put(THIS_MODULE);

  return 0;
}

/* 
 * Called when a process, which already opened the dev file, attempts to
 * read from it.
 */
static ssize_t device_read(struct file *filp,	/* see include/linux/fs.h   */
			   char *buffer,	/* buffer to fill with data */
			   size_t length,	/* length of the buffer     */
			   loff_t * offset)
{
  /*
   * Number of bytes actually written to the buffer 
   */
  int bytes_read = 0;

  /*
   * If we're at the end of the message, 
   * return 0 signifying end of file 
   */
  if (*msg_Ptr == 0)
    return 0;

  /* 
   * Actually put the data into the buffer 
   */
  while (length && *msg_Ptr) {

    /* 
     * The buffer is in the user data segment, not the kernel 
     * segment so "*" assignment won't work.  We have to use 
     * put_user which copies data from the kernel data segment to
     * the user data segment. 
     */
    put_user(*(msg_Ptr++), buffer++);

    length--;
    bytes_read++;
  }

  /* 
   * Most read functions return the number of bytes put into the buffer
   */
  return bytes_read;
}

static struct spi_driver spi_test_driver = {
  .driver = {
    .name = "slotcardriver",
    //    .bus = &spi_bus_type,
    .owner = THIS_MODULE,
  },
  .probe = slotcar_probe,
  .remove = slotcar_remove,
  // .suspend = slotcar_suspend,
  //.resume = slotcar_resume,
};

/*  
 * Called when a process writes to dev file: echo "hi" > /dev/hello 
 */
static ssize_t
device_write(struct file *filp, const char *buff, size_t len, loff_t * off)
{
  char temp[100];
  int i;
  unsigned long hej;

  printk("len: %d\r\n",len);
  hej = copy_from_user(temp,buff,len);

  for(i=0;i<len+2;i++){
    printk("temp[%d]=%d\r\n",i,temp[i]);
  }
  temp[len] = '\0';
  printk("copy from user ret %lu\r\n",hej);
  //  spi_write(mydev,temp,len);
  printk("%s\r\n",temp);

  

  return len;

}
/*
static struct spi_board_info fpga_spi_info[] __initdata = {
{
    .modalias    = "fpga",
    .max_speed_hz    = 1*1000*1000,
    .bus_num    = 0,
    .chip_select    = 0,
},
};
*/
static int __init add_slotcar_device_to_bus(void)
{
  //spi_register_board_info(spi_board_info, ARRAY_SIZE(spi_board_info));
  struct spi_master *spi_master;
  struct spi_device *spi_device;
  struct device *pdev;
  char buff[64];
  int status = 0;

  const int SPI_BUS = 0;
  const int SPI_BUS_CS = 0;
  const int SPI_BUS_SPEED = 1000000;
  spi_master = spi_busnum_to_master(SPI_BUS);
  if (!spi_master) {
    printk(KERN_ALERT "spi_busnum_to_master(%d) returned NULL\n",
	   SPI_BUS);
    printk(KERN_ALERT "Missing modprobe omap2_mcspi?\n");
    return -1;
  }

  spi_device = spi_alloc_device(spi_master);
  if (!spi_device) {
    put_device(&spi_master->dev);
    printk(KERN_ALERT "spi_alloc_device() failed\n");
    return -1;
  }

  spi_device->chip_select = SPI_BUS_CS;

  /* Check whether this SPI bus.cs is already claimed */
  snprintf(buff, sizeof(buff), "%s.%u",
	   dev_name(&spi_device->master->dev),
	   spi_device->chip_select);

  pdev = bus_find_device_by_name(spi_device->dev.bus, NULL, buff);
  if (pdev) {
    /* We are not going to use this spi_device, so free it */
    spi_dev_put(spi_device);

    /*
     * There is already a device configured for this bus.cs
     * It is okay if it us, otherwise complain and fail.
     */
    if (pdev->driver && pdev->driver->name &&
	strcmp(DEVICE_NAME, pdev->driver->name)) {
      printk(KERN_ALERT
	     "Driver [%s] already registered for %s\n",
	     pdev->driver->name, buff);
      status = -1;
    }
  } else {
    spi_device->max_speed_hz = SPI_BUS_SPEED;
    spi_device->mode = SPI_MODE_0;
    spi_device->bits_per_word = 8;
    spi_device->irq = -1;
    spi_device->controller_state = NULL;
    spi_device->controller_data = NULL;
    strlcpy(spi_device->modalias, DEVICE_NAME, SPI_NAME_SIZE);

    status = spi_add_device(spi_device);	
    if (status < 0) {	
      spi_dev_put(spi_device);
      printk(KERN_ALERT "spi_add_device() failed: %d\n",
	     status);	
    }	
  }

  put_device(&spi_master->dev);

  return status;
}

static int __init slotcar_init_spi( void )
{
  int error = 0;
  error = spi_register_driver(&spi_test_driver);
  if (error < 0) {
    printk(KERN_ALERT "spi_register_driver() failed %d in function %s\n", error,  __func__);
    return error;
  }

  error = add_slotcar_device_to_bus();
  if (error < 0) {
    printk(KERN_ALERT "add_spike_to_bus() failed %d in function %s\n", error,  __func__);
    spi_unregister_driver(&spi_test_driver);
    return error;
  }
  return error;
}

static int __init slotcar_init( void )
{
  int error = 0;

  reg_chdriver();

  //  slotcar_init_class??

  error = slotcar_init_spi();
  if (error < 0) {
    printk(KERN_ALERT "slotcar_init_spi() failed %d in function %s\n", error, __func__);
    return error;
  }

  return error;
}
 
static void __exit slotcar_exit( void )
{
  spi_unregister_driver(&spi_test_driver);
  unreg_chdriver();
}






MODULE_LICENSE("GPL");
MODULE_AUTHOR("Erik & Thommy");
MODULE_DESCRIPTION("Driver for slotcar");
MODULE_VERSION("0.1");

//module_spi_driver(spi_test_driver); 
module_init(slotcar_init);
module_exit(slotcar_exit);
