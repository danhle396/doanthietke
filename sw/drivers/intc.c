// intc.c - INTC driver; irq_external_handler() dispatches MEI to the
// peripheral ISRs according to INTC.ACTIVE.
#include "intc.h"
#include "platform.h"
#include "csr.h"

void intc_enable(uint32_t mask)  { REG32(INTC_ENABLE) |= mask; }
void intc_disable(uint32_t mask) { REG32(INTC_ENABLE) &= ~mask; }
uint32_t intc_active(void)  { return REG32(INTC_ACTIVE); }
uint32_t intc_pending(void) { return REG32(INTC_PENDING); }

void __attribute__((weak)) spi_isr(void)  { REG32(SPI_IRQ_EN) = 0; }
void __attribute__((weak)) gpio_isr(void) { REG32(GPIO_IRQ_EN) = 0; }

void irq_external_handler(void) {
  uint32_t act = intc_active();
  if (act & INTC_SRC_UART) uart_isr();
  if (act & INTC_SRC_SPI)  spi_isr();
  if (act & INTC_SRC_GPIO) gpio_isr();
}
