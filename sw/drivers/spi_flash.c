// spi_flash.c - SPI NOR flash helpers (JEDEC ID, READ, WREN, RDSR, PP, SE).
#include "spi_flash.h"
#include "spi.h"

int flash_use_irq = 0;

static void xfer(const uint8_t *tx, uint8_t *rx, int n) {
  if (flash_use_irq) spi_xfer_buf_irq(tx, rx, n);
  else               spi_xfer_buf(tx, rx, n);
}

static void cmd_addr(uint8_t cmd, uint32_t addr) {
  uint8_t h[4] = {cmd, (uint8_t)(addr >> 16), (uint8_t)(addr >> 8), (uint8_t)addr};
  xfer(h, 0, 4);
}

void flash_read_id(uint8_t id[3]) {
  uint8_t tx[4] = {0x9F, 0, 0, 0}, rx[4];
  spi_select(FLASH_CS);
  xfer(tx, rx, 4);
  spi_deselect();
  id[0] = rx[1]; id[1] = rx[2]; id[2] = rx[3];
}

uint8_t flash_read_status(void) {
  uint8_t tx[2] = {0x05, 0}, rx[2];
  spi_select(FLASH_CS);
  spi_xfer_buf(tx, rx, 2);
  spi_deselect();
  return rx[1];
}

void flash_write_enable(void) {
  uint8_t c = 0x06;
  spi_select(FLASH_CS);
  spi_xfer_buf(&c, 0, 1);
  spi_deselect();
}

int flash_wait_busy(void) {
  int polls = 0;
  do polls++; while (flash_read_status() & 1u);
  return polls;
}

void flash_read(uint32_t addr, uint8_t *buf, int n) {
  spi_select(FLASH_CS);
  cmd_addr(0x03, addr);
  xfer(0, buf, n);
  spi_deselect();
}

void flash_page_program(uint32_t addr, const uint8_t *buf, int n) {
  flash_write_enable();
  spi_select(FLASH_CS);
  cmd_addr(0x02, addr);
  xfer(buf, 0, n);
  spi_deselect();
}

void flash_sector_erase(uint32_t addr) {
  flash_write_enable();
  spi_select(FLASH_CS);
  cmd_addr(0x20, addr);
  spi_deselect();
}
