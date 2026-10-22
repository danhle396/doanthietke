// uart.h - UART driver: polling API and interrupt-driven RX/TX ring buffers.
#ifndef UART_H
#define UART_H

#include <stdint.h>

#define UART_DIV_115200_50MHZ 26u   // 16 x 27 clocks per bit
#define UART_DIV_SIM          0u    // 16 clocks per bit (fast simulation)

void     uart_init(uint32_t baud_div, uint32_t ctrl);  // ctrl: UART_CTRL_* bits
// polling API
void     uart_putc(char c);
void     uart_puts(const char *s);
int      uart_getc(void);          // blocks until a byte is received
int      uart_try_getc(void);      // -1 if the RX FIFO is empty
void     uart_flush(void);         // wait until TX FIFO empty and shifter idle
uint32_t uart_status(void);
void     uart_clear_errors(void);  // W1C IRQ_STATUS.ERR (clears STATUS[7:5])
// interrupt API (RX ring buffer filled by uart_isr)
void     uart_rx_irq_start(void);  // RX_WM_LVL = 1, enable RX_WM + ERR irq, INTC source
void     uart_rx_irq_stop(void);
int      uart_rx_available(void);
int      uart_rx_read(void);       // -1 if the ring buffer is empty
uint32_t uart_rx_dropped(void);    // bytes lost because the ring buffer was full
uint32_t uart_err_events(void);    // ERR interrupts seen by the ISR
void     uart_isr(void);           // called from the external interrupt dispatcher

#endif
