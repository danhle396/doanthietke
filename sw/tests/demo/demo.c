// demo.c - SoC demonstration at the real UART speed (115200 baud @ 50 MHz).
//   1. The timer interrupts every TICK cycles; on each tick 16 bytes are read
//      from the SPI flash and printed in hex (3 ticks).
//   2. Interactive commands received by the UART RX interrupt, one per line:
//        r : read and print 16 bytes at 0x001000
//        w : erase sector 0x001000 and program "RISC-V SoC DEMO!"
//        s : print the performance counters
//        q : quit
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "uart.h"
#include "spi.h"
#include "spi_flash.h"
#include "timer.h"
#include "perf.h"
#include "xprintf.h"

#define TICK     500000u   // 10 ms: longer than printing one line at 115200 baud
#define N_TICKS  3
#define RW_ADDR  0x001000u

static volatile int ticks, tick_flag;

void irq_timer_handler(void) {
  ticks++;
  tick_flag = 1;
  if (ticks >= N_TICKS) {
    timer_irq_disable();
    timer_set_cmp(~0ull);
  } else {
    timer_set_cmp(timer_get_cmp() + TICK);
  }
}

static void dump16(uint32_t addr) {
  uint8_t b[16];
  flash_read(addr, b, 16);
  xprintf("0x%06x:", addr);
  for (int i = 0; i < 16; i++) xprintf(" %02x", b[i]);
  xprintf(" |");
  // '>' is reserved for the prompt (the test bench waits for it)
  for (int i = 0; i < 16; i++) xputc((b[i] >= 32 && b[i] < 127 && b[i] != '>') ? (char)b[i] : '.');
  xprintf("|\n");
}

static int read_line(char *buf, int max) {
  int n = 0;
  for (;;) {
    int c = uart_rx_read();
    if (c < 0) { __asm__ volatile ("wfi"); continue; }
    if (c == '\r') continue;
    if (c == '\n') break;
    if (n < max - 1) buf[n++] = (char)c;
  }
  buf[n] = 0;
  return n;
}

int main(void) {
  static const char msg[16] = "RISC-V SoC DEMO!";
  perf_snapshot_t p0, p1;
  char line[16];
  uint8_t id[3];

  perf_snapshot(&p0);
  xprintf("RV32IMC SoC demo: UART 115200 baud, SPI flash, TIMER64\n");
  spi_init(1, 0, 0);
  flash_read_id(id);
  xprintf("flash id: %02x %02x %02x\n", id[0], id[1], id[2]);

  uart_rx_irq_start();
  csr_set(mie, MIE_MEIE);
  timer_set_cmp(timer_mtime() + TICK);
  timer_irq_enable();
  irq_global_enable();

  while (ticks < N_TICKS || tick_flag) {
    if (tick_flag) {
      tick_flag = 0;
      xprintf("[tick %d] ", ticks);
      dump16((uint32_t)(ticks - 1) * 16u);
    } else {
      __asm__ volatile ("wfi");
    }
  }

  for (;;) {
    xprintf("> ");
    read_line(line, sizeof(line));
    xprintf("%s\n", line);
    if (line[0] == 'r') {
      dump16(RW_ADDR);
    } else if (line[0] == 'w') {
      flash_sector_erase(RW_ADDR);
      int pe = flash_wait_busy();
      flash_page_program(RW_ADDR, (const uint8_t *)msg, 16);
      int pp = flash_wait_busy();
      xprintf("write done (erase polls=%d, program polls=%d)\n", pe, pp);
    } else if (line[0] == 's') {
      perf_snapshot(&p1);
      perf_print("demo", &p0, &p1);
    } else if (line[0] == 'q') {
      xprintf("bye\n");
      break;
    } else {
      xprintf("unknown command '%s'\n", line);
    }
  }
  return 0;
}
