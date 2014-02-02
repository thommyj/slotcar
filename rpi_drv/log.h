
#ifndef __LOG_H
#define __LOG_H

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

extern int log_depth;
#define LOG(type, msg, ...)                                             \
  do {                                                                  \
    printk("\033[34m%s\t\033[0m: %4d : %s: ", __FILE_NAME__, __LINE__, type);	\
    int lkx;								\
    for(lkx=0; lkx<log_depth; lkx++) {					\
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
    log_depth++;						\
  } while(0)

#if 1
#define LOG_EXIT()						\
  do {								\
    log_depth--;						\
    LOG("\033[37;1mEXIT    ", "%s%s", __func__, "\033[0m");	\
  } while (0)
#else
#define LOG_EXIT()						\
  do {								\
    log_depth--;						\
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
extern const char driver_name[]; // Should be slot car...


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

void print_cdev(struct cdev *c);
void print_spi_device_info(spi_device_t *spi_dev);
void print_driver_data(driver_data_t *data);

#endif
