// spi.c - SPI master driver.
#include "spi.h"
#include "platform.h"
#include "intc.h"
#include "csr.h"

#define SPI_FIFO 16

static volatile int      done_flag;
static volatile uint32_t done_count;

void spi_init(uint32_t clk_div, uint32_t mode, int lsb_first) {
  REG32(SPI_CS) = 0xF;
  REG32(SPI_CLK_DIV) = clk_div;
  REG32(SPI_CTRL) = SPI_CTRL_EN | ((mode & 2) ? SPI_CTRL_CPOL : 0) |
                    ((mode & 1) ? SPI_CTRL_CPHA : 0) | (lsb_first ? SPI_CTRL_LSB_FIRST : 0);
}

void spi_select(int cs) { REG32(SPI_CS) = 0xFu & ~(1u << cs); }
void spi_deselect(void) {
  while (REG32(SPI_STATUS) & SPI_ST_BUSY) ;
  REG32(SPI_CS) = 0xF;
}

uint8_t spi_xfer(uint8_t b) {
  uint32_t d;
  REG32(SPI_DATA) = b;
  while ((d = REG32(SPI_DATA)) & (1u << 31)) ;   // wait for the received byte
  return (uint8_t)d;
}

void spi_xfer_buf(const uint8_t *tx, uint8_t *rx, int n) {
  int sent = 0, got = 0;
  while (got < n) {
    // keep at most FIFO-depth bytes in flight so the RX FIFO cannot overflow
    while (sent < n && sent - got < SPI_FIFO) {
      REG32(SPI_DATA) = tx ? tx[sent] : 0xFF;
      sent++;
    }
    uint32_t d = REG32(SPI_DATA);
    if (!(d & (1u << 31))) {
      if (rx) rx[got] = (uint8_t)d;
      got++;
    }
  }
}

void spi_irq_mode(int enable) {
  REG32(SPI_IRQ_STATUS) = SPI_IRQ_DONE | SPI_IRQ_OVERRUN;
  if (enable) {
    REG32(SPI_IRQ_EN) = SPI_IRQ_DONE;
    intc_enable(INTC_SRC_SPI);
    csr_set(mie, MIE_MEIE);
  } else {
    REG32(SPI_IRQ_EN) = 0;
    intc_disable(INTC_SRC_SPI);
  }
}

void spi_isr(void) {
  if (REG32(SPI_IRQ_STATUS) & SPI_IRQ_DONE) {
    REG32(SPI_IRQ_STATUS) = SPI_IRQ_DONE;
    done_count++;
    done_flag = 1;
  }
}

uint32_t spi_done_irqs(void) { return done_count; }

void spi_xfer_buf_irq(const uint8_t *tx, uint8_t *rx, int n) {
  int pos = 0;
  while (pos < n) {
    int chunk = (n - pos > SPI_FIFO) ? SPI_FIFO : n - pos;
    done_flag = 0;
    for (int i = 0; i < chunk; i++) REG32(SPI_DATA) = tx ? tx[pos + i] : 0xFF;
    while (!done_flag) __asm__ volatile ("wfi");
    for (int i = 0; i < chunk; i++) {
      uint32_t d = REG32(SPI_DATA);
      if (rx) rx[pos + i] = (uint8_t)d;
    }
    pos += chunk;
  }
}
