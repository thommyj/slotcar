#include "log.h"

// Driver name that should match the name of the struct spi_board_info
// in the arcitecture file when building the linux kernel.
const char driver_name[] = "spidev"; // Should be slot car...

int log_depth=0;

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

