// spi_flash.c - SPI NOR flash on CS0: JEDEC ID, initial content, sector
// erase, page program, read-back; WIP polling; data phases use the SPI DONE
// interrupt (CPU sleeps in wfi); JEDEC ID again in SPI mode 3.
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "spi.h"
#include "spi_flash.h"
#include "testlib.h"

#define TEST_ADDR 0x001000u

static uint8_t wbuf[256], rbuf[256];

int main(void) {
  uint8_t id[3];
  int polls;

  xprintf("spi_flash\n");
  spi_init(1, 0, 0);                         // SCLK = clk/4, mode 0, MSB first
  flash_read_id(id);
  xprintf("jedec id: %02x %02x %02x\n", id[0], id[1], id[2]);
  T_CHECK(id[0] == 0xEF && id[1] == 0x40 && id[2] == 0x16, "JEDEC ID");

  flash_read(0x000000, rbuf, 16);           // factory pattern (a * 7 + 3)
  for (int i = 0; i < 16; i++) T_CHECK(rbuf[i] == (uint8_t)(i * 7 + 3), "initial byte %d", i);

  // interrupt-driven data phases from here on
  spi_irq_mode(1);
  irq_global_enable();
  flash_use_irq = 1;

  flash_sector_erase(TEST_ADDR);
  T_CHECK(flash_read_status() & 1u, "WIP must be set after erase");
  polls = flash_wait_busy();
  xprintf("erase: wip polls=%d\n", polls);
  T_CHECK(polls > 1, "erase finished too early");
  flash_read(TEST_ADDR, rbuf, 256);
  for (int i = 0; i < 256; i++) T_CHECK(rbuf[i] == 0xFF, "erased byte %d = %x", i, rbuf[i]);

  for (int i = 0; i < 256; i++) wbuf[i] = (uint8_t)(i ^ 0x5A);
  flash_page_program(TEST_ADDR, wbuf, 256);
  polls = flash_wait_busy();
  xprintf("program: wip polls=%d\n", polls);
  T_CHECK(polls > 1, "program finished too early");
  T_CHECK((flash_read_status() & 2u) == 0, "WEL must clear after program");
  flash_read(TEST_ADDR, rbuf, 256);
  int bad = 0;
  for (int i = 0; i < 256; i++) if (rbuf[i] != wbuf[i]) bad++;
  T_CHECK(bad == 0, "%d bytes differ", bad);
  xprintf("verify: %d bytes ok\n", 256 - bad);

  // program without WREN must not change the data
  {
    uint8_t h[8] = {0x02, 0x00, 0x10, 0x00, 0, 0, 0, 0};
    spi_select(FLASH_CS);
    spi_xfer_buf_irq(h, 0, 8);
    spi_deselect();
  }
  flash_read(TEST_ADDR, rbuf, 4);
  T_CHECK(rbuf[0] == wbuf[0] && rbuf[3] == wbuf[3], "program without WREN changed data");

  flash_use_irq = 0;
  spi_irq_mode(0);
  spi_init(1, 3, 0);                         // mode 3
  flash_read_id(id);
  xprintf("mode3 jedec id: %02x %02x %02x\n", id[0], id[1], id[2]);
  T_CHECK(id[0] == 0xEF && id[1] == 0x40 && id[2] == 0x16, "JEDEC ID mode 3");
  xprintf("done irqs=%u\n", spi_done_irqs());
  T_CHECK(spi_done_irqs() > 10, "DONE interrupts were not used");
  return t_result("spi_flash");
}
