
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <asm/uaccess.h>

#include <linux/spi/spi.h>

#include "log.h"
#include "fop.h"

/**
 * file operations struct
 */
const struct file_operations fops_slotcar = {
  .owner = THIS_MODULE,
  .read  = fop_slotcar_read,
  .write = fop_slotcar_write,
  .open  = fop_slotcar_open,
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
ssize_t fop_slotcar_write(struct file *filp, const char *buff, size_t len, loff_t *offp)
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
ssize_t fop_slotcar_read(struct file *filp, char __user *buff, size_t count, loff_t *offp)
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
int fop_slotcar_open(struct inode *inode, struct file *filp)
{
  LOG_ENTRY();

  // neccessary?
  driver_data_t *data = container_of(inode->i_cdev, driver_data_t, cdev);
  filp->private_data = data;

  int status = 0;

  LOG_EXIT();
  return status;
}

