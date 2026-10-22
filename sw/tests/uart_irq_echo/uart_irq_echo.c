// uart_irq_echo.c - interrupt-driven UART echo, then RX overrun detection.
//   Phase 1: RX_WM interrupt fills a ring buffer, main echoes every byte
//            until '\n'; the line is compared and the overrun flag checked.
//   Phase 2: RX interrupts off; the BFM sends 21 bytes into the 16-entry
//            FIFO -> RX_OVERRUN; the first 16 bytes are kept; W1C clears it.
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "uart.h"
#include "testlib.h"

static const char line1[] = "The quick brown fox jumps over the lazy dog 0123456789\n";
static const char line2[] = "ABCDEFGHIJKLMNOPQRST\n";

int main(void) {
  char buf[80];
  int n = 0;

  xprintf("uart_irq_echo\n");
  uart_rx_irq_start();
  csr_set(mie, MIE_MEIE);
  irq_global_enable();
  xprintf(">");                         // prompt: the BFM sends line 1
  for (;;) {
    int c = uart_rx_read();
    if (c < 0) { __asm__ volatile ("wfi"); continue; }
    uart_putc((char)c);
    if (n < (int)sizeof(buf) - 1) buf[n++] = (char)c;
    if (c == '\n') break;
  }
  buf[n] = 0;
  uint32_t st = uart_status();
  T_CHECK(n == (int)sizeof(line1) - 1, "length %d", n);
  for (int i = 0; i < n && line1[i]; i++) T_CHECK(buf[i] == line1[i], "byte %d", i);
  T_CHECK(!(st & UART_ST_RX_OVERRUN), "unexpected overrun");
  T_CHECK(uart_rx_dropped() == 0, "ring buffer dropped bytes");
  xprintf("echo ok: %d bytes, overrun=%d, dropped=%d\n", n, (st & UART_ST_RX_OVERRUN) ? 1 : 0,
          (int)uart_rx_dropped());

  // ---- phase 2: overrun ----
  irq_global_disable();
  uart_rx_irq_stop();
  xprintf("overrun test\n>");           // prompt: the BFM sends line 2 (21 bytes)
  uint32_t t = 0;
  while (!(uart_status() & UART_ST_RX_OVERRUN) && t++ < 200000) ;
  delay_cycles(16 * 12 * 8);            // let the rest of the line arrive (dropped)
  st = uart_status();
  int level = (st >> 16) & 0x1F;
  T_CHECK(st & UART_ST_RX_OVERRUN, "overrun not detected");
  T_CHECK(st & UART_ST_RX_FULL, "RX not full");
  T_CHECK(level == 16, "level %d", level);
  for (int i = 0; i < 16; i++) {
    int c = uart_try_getc();
    buf[i] = (char)c;
    T_CHECK(c == line2[i], "kept byte %d = %d", i, c);
  }
  buf[16] = 0;
  T_CHECK(uart_try_getc() < 0, "FIFO should be empty");
  xprintf("overrun detected: level=%d first=%s\n", level, buf);
  uart_clear_errors();
  T_CHECK(!(uart_status() & (UART_ST_RX_OVERRUN | UART_ST_FRAME_ERR | UART_ST_PARITY_ERR)),
          "error flags not cleared");
  xprintf("overrun cleared\n");
  return t_result("uart_irq_echo");
}
