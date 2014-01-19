
#include <linux/cdev.h>
#include <linux/spi/spi.h>
#include <linux/string.h>

#define SPI_TRANSFER_CODE_OK       0xAA
#define SPI_TRANSFER_WAIT_FOR_READ 0xAA

#define SPI_ADDRESS_MASK           0x3F


#define SPI_EXTERNAL               0x00
#define SPI_INTERNAL               0x40

#define SPI_READ                   0x00
#define SPI_WRITE                  0x80

#define FPGA_MEMORY_SIZE           SPI_ADDRESS_MASK


// To remove "ISO C90 forbids mixed declarations and code [-Wdeclaration-after-statement]" warning
#pragma GCC diagnostic ignored "-Wdeclaration-after-statement"


#define __FILE_NAME__ (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__)

int depth =0;
#define LOG(type, msg, ...)                                             \
  do {                                                                  \
    printk("\033[34m%s\t\033[0m: %4d : %s: ", __FILE_NAME__, __LINE__, type);	\
    int lkx;								\
    for(lkx=0; lkx<depth; lkx++) {					\
      printk("  ");							\
    }									\
    printk(msg, ##__VA_ARGS__);						\
    printk("\n");							\
  } while(0)

#define LOG_ERROR(msg, ...) LOG("\033[31;1mERROR   \033[0m", msg, ##__VA_ARGS__)
#define LOG_WARNING(msg, ...) LOG("\033[33mWARNING \033[0m", msg, ##__VA_ARGS__)
#define LOG_DEBUG(msg, ...) LOG("\033[32mNOTE    \033[0m", msg, ##__VA_ARGS__)

// set to 1 to enable function call trace
#if 1
#define LOG_ENTRY()						\
  do {								\
    LOG("\033[37;1mENTRY   ", "%s%s", __func__, "\033[0m");	\
    depth++;							\
  } while(0)

#if 1
#define LOG_EXIT()						\
  do {								\
    depth--;							\
    LOG("\033[37;1mEXIT    ", "%s%s", __func__, "\033[0m");	\
  } while (0)
#else
#define LOG_EXIT()						\
  do {								\
    depth--;							\
  } while (0)
#endif
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
const char driver_name[] = "spidev"; // Should be slot car...


typedef struct spi_device spi_device_t;

typedef struct {
  // This struct holds the device numbers (major and minor)
  dev_t devt;

  // char device structure
  struct cdev cdev;

  //
  struct class *class;

  //
  spi_device_t *spi_device;
  spi_device_t *spi_device2;
} driver_data_t;

void print_cdev(struct cdev *c)
{
  LOG_DEBUG("cdev");
  //  LOG_DEBUG("  kobjr");
  //LOG_DEBUG("  owner");
  //LOG_DEBUG("  fops");
  //  LOG_DEBUG("  list");
  LOG_DEBUG("  dev");
  LOG_DEBUG("    Major: %i", MAJOR(c->dev));
  LOG_DEBUG("    Minor: %i", MINOR(c->dev));
  LOG_DEBUG("  count: %i", c->count);
}

void print_spi_device_info(spi_device_t *spi_dev)
{
  if (!spi_dev) {
    LOG_ERROR("Cannot print null spi_device");
    return;
  }
  LOG_DEBUG("spi_device");
  LOG_DEBUG("  master");
  LOG_DEBUG("    bus_num: %i", spi_dev->master->bus_num);
  //  LOG_DEBUG("  max speed(hz): %i", spi_dev->max_speed_hz);
  LOG_DEBUG("  chip_select: %i", spi_dev->chip_select);
  LOG_DEBUG("  mode: %i", spi_dev->mode);
  //  LOG_DEBUG("  bits_per_word: %i", spi_dev->bits_per_word);
  //  LOG_DEBUG("  irq: %i", spi_dev->irq);
  ////LOG_DEBUG("  controller state: %i", spi_dev->controller_state);
  ////LOG_DEBUG("  controller data: %i", spi_dev->controller_data);
  //  LOG_DEBUG("  alias: \"%s\"", spi_dev->modalias);
}


void print_driver_data(driver_data_t *data)
{
  if (!data) {
    LOG_ERROR("Cannot print null driver data");
    return;
  }
  print_cdev(&data->cdev);
  print_spi_device_info(data->spi_device);
}
