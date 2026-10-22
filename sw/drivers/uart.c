// uart.c - UART driver.
#include "uart.h"
#include "platform.h"
#include "intc.h"

#define RB_SIZE 64u

static volatile uint8_t  rb[RB_SIZE];
static volatile uint32_t rb_head, rb_tail, rb_dropped, err_events;

void uart_init(uint32_t baud_div, uint32_t ctrl) {
  REG32(UART_BAUD_DIV) = baud_div;
  REG32(UART_CTRL) = ctrl;
}

void uart_putc(char c) {
  while (REG32(UART_STATUS) & UART_ST_TX_FULL) ;
  REG32(UART_DATA) = (uint8_t)c;
}

void uart_puts(const char *s) {
  while (*s) uart_putc(*s++);
}

int uart_try_getc(void) {
  uint32_t d = REG32(UART_DATA);
  return (d & UART_DATA_RX_EMPTY) ? -1 : (int)(d & 0xFF);
}

int uart_getc(void) {
  int c;
  while ((c = uart_try_getc()) < 0) ;
  return c;
}

void uart_flush(void) {
  while (!(REG32(UART_STATUS) & UART_ST_TX_IDLE)) ;
}

uint32_t uart_status(void) { return REG32(UART_STATUS); }

void uart_clear_errors(void) { REG32(UART_IRQ_STATUS) = UART_IRQ_ERR; }

void uart_rx_irq_start(void) {
  rb_head = rb_tail = rb_dropped = 0;
  REG32(UART_WATERMARK) = (1u << 16);              // RX_WM_LVL = 1, TX_WM_LVL = 0
  REG32(UART_IRQ_EN) = UART_IRQ_RX_WM | UART_IRQ_ERR;
  intc_enable(INTC_SRC_UART);
}

void uart_rx_irq_stop(void) {
  REG32(UART_IRQ_EN) = 0;
  intc_disable(INTC_SRC_UART);
}

int uart_rx_available(void) { return (int)(rb_head - rb_tail); }

int uart_rx_read(void) {
  if (rb_head == rb_tail) return -1;
  uint8_t c = rb[rb_tail % RB_SIZE];
  rb_tail++;
  return c;
}

uint32_t uart_rx_dropped(void) { return rb_dropped; }
uint32_t uart_err_events(void) { return err_events; }

// Drain the RX FIFO into the ring buffer; acknowledge errors.
void uart_isr(void) {
  if (REG32(UART_IRQ_STATUS) & UART_IRQ_ERR) {
    err_events++;
    REG32(UART_IRQ_STATUS) = UART_IRQ_ERR;
  }
  for (;;) {
    uint32_t d = REG32(UART_DATA);
    if (d & UART_DATA_RX_EMPTY) break;
    if (rb_head - rb_tail < RB_SIZE) {
      rb[rb_head % RB_SIZE] = (uint8_t)d;
      rb_head++;
    } else {
      rb_dropped++;
    }
  }
}
