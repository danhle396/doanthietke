// spi_flash.h - W25Q-style SPI NOR flash commands on CS0.
#ifndef SPI_FLASH_H
#define SPI_FLASH_H

#include <stdint.h>

#define FLASH_CS 0
extern int flash_use_irq;   // 1: data phases use spi_xfer_buf_irq()

void    flash_read_id(uint8_t id[3]);
uint8_t flash_read_status(void);
void    flash_write_enable(void);
int     flash_wait_busy(void);    // returns the number of RDSR polls
void    flash_read(uint32_t addr, uint8_t *buf, int n);
void    flash_page_program(uint32_t addr, const uint8_t *buf, int n);  // n <= 256, same page
void    flash_sector_erase(uint32_t addr);

#endif
