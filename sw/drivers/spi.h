// spi.h - SPI master driver: polling and DONE-interrupt transfers.
#ifndef SPI_H
#define SPI_H

#include <stdint.h>

void    spi_init(uint32_t clk_div, uint32_t mode, int lsb_first);  // mode 0..3, enables
void    spi_select(int cs);       // assert CS_N[cs] (others high)
void    spi_deselect(void);
uint8_t spi_xfer(uint8_t b);      // polling, one byte
void    spi_xfer_buf(const uint8_t *tx, uint8_t *rx, int n);       // polling; tx/rx may be NULL
// interrupt-driven: the FIFO is filled in chunks of 16, the CPU sleeps (wfi)
// until the DONE interrupt, then drains the RX FIFO.
void    spi_irq_mode(int enable);  // route DONE through INTC (MEI)
void    spi_xfer_buf_irq(const uint8_t *tx, uint8_t *rx, int n);
uint32_t spi_done_irqs(void);
void    spi_isr(void);

#endif
