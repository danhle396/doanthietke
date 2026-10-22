// intc.h - interrupt controller driver and external-interrupt dispatcher.
#ifndef INTC_H
#define INTC_H

#include <stdint.h>

void     intc_enable(uint32_t mask);    // INTC_SRC_* bits
void     intc_disable(uint32_t mask);
uint32_t intc_active(void);
uint32_t intc_pending(void);

// Peripheral handlers called by the dispatcher (weak defaults disable the source).
void uart_isr(void);
void spi_isr(void);
void gpio_isr(void);

#endif
