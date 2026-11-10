// board_demo.c - Interactive demo for the DE2 board (UART 115200 8N1).
//   LEDR[7:0]  mirror SW[7:0], updated by the GPIO edge interrupt
//   LEDR[15:8] seconds counter, updated by the machine-timer interrupt
//   UART commands (one per line, RX interrupt + ring buffer):
//     h help, i info, s switches, b benchmark (perf counters),
//     f SPI flash JEDEC ID (W25Q module on GPIO_0), q quit
//   The benchmark runs twice with interrupts disabled; the second run starts
//   from a deterministic predictor state, so its cycle count must equal the
//   one obtained in RTL simulation of the same binary.
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "uart.h"
#include "gpio.h"
#include "timer.h"
#include "intc.h"
#include "spi.h"
#include "spi_flash.h"
#include "perf.h"
#include "xprintf.h"

#ifndef CPU_HZ
#define CPU_HZ 24000000u
#endif
#define TIMER_PRESCALE (CPU_HZ / 1000000u - 1u)  // mtime counts microseconds
#define TICK_US        500000u                    // timer interrupt every 0.5 s
#define N_WORDS        1024

static volatile uint32_t half_seconds;
static volatile uint32_t sw_events;
static uint64_t next_cmp;
static uint32_t buf[N_WORDS];

static void update_leds(void) {
  uint32_t secs = half_seconds / 2u;
  gpio_write(((secs & 0xFFu) << 8) | (gpio_read() & 0xFFu));
}

void irq_timer_handler(void) {
  next_cmp += TICK_US;
  timer_set_cmp(next_cmp);
  half_seconds++;
  update_leds();
}

void gpio_isr(void) {
  gpio_irq_clear(gpio_irq_status());
  // wait for the opposite edge on every switch: falling if it is high now
  gpio_irq_config(0xFFu, gpio_read() & 0xFFu);
  sw_events++;
  update_leds();
}

// CRC-32 over a generated buffer plus a multiply/divide chain.
static uint32_t workload(void) {
  uint32_t crc = 0xFFFFFFFFu, acc = 1u;
  for (int i = 0; i < N_WORDS; i++) buf[i] = (uint32_t)i * 2654435761u;
  for (int i = 0; i < N_WORDS; i++) {
    uint32_t x = buf[i];
    for (int k = 0; k < 32; k++) {
      if ((crc ^ x) & 1u) crc = (crc >> 1) ^ 0xEDB88320u;
      else                crc >>= 1;
      x >>= 1;
    }
  }
  for (uint32_t i = 1; i < 2000u; i++) acc = acc * 31u + buf[i % N_WORDS] / i;
  return ~crc ^ acc;
}

static void cmd_bench(void) {
  perf_snapshot_t s, e;
  uint32_t r = 0;
  irq_global_disable();
  for (int run = 1; run <= 2; run++) {
    perf_snapshot(&s);
    r = workload();
    perf_snapshot(&e);
    xprintf("run %d:\n", run);
    perf_print("board_demo", &s, &e);
  }
  irq_global_enable();
  xprintf("result = 0x%08x\n", r);
}

static void cmd_info(void) {
  uint32_t cyc = (uint32_t)rd_mcycle(), ins = (uint32_t)rd_minstret();
  xprintf("CPU      : rv_core RV32IMC, %u Hz, misa = 0x%08x\n", (uint32_t)CPU_HZ,
          csr_read(misa));
  xprintf("uptime   : %u s, switch events: %u\n", half_seconds / 2u, sw_events);
  xprintf("mcycle   : %u  minstret: %u  CPI x1000: %u\n", cyc, ins,
          ins ? (uint32_t)(((uint64_t)cyc * 1000u) / ins) : 0u);
}

static void cmd_flash(void) {
  uint8_t id[3];
  spi_init(1, 0, 0);  // SCLK = clk / 4, mode 0, MSB first
  flash_read_id(id);
  xprintf("JEDEC ID : %02x %02x %02x", id[0], id[1], id[2]);
  if ((id[0] == 0xFF && id[1] == 0xFF) || (id[0] == 0 && id[1] == 0))
    xprintf("  (no flash on GPIO_0)\n");
  else
    xprintf("\n");
}

static void help(void) {
  xprintf("commands: h help | i info | s switches | b benchmark | f flash ID | q quit\n");
}

// Returns the first printable character of the next non-empty line (echoed).
static char read_cmd(void) {
  char first = 0;
  for (;;) {
    int c = uart_rx_read();
    if (c < 0) continue;
    if (c == '\r' || c == '\n') {
      if (first) {
        uart_putc('\n');
        return first;
      }
      continue;
    }
    if (!first && c > ' ') first = (char)c;
    uart_putc((char)c);
  }
}

int main(void) {
  gpio_set_dir(0xFFFFu);
  timer_config(1, TIMER_PRESCALE);
  next_cmp = timer_mtime() + TICK_US;
  timer_set_cmp(next_cmp);
  gpio_irq_clear(0xFFFFu);
  gpio_irq_config(0xFFu, gpio_read() & 0xFFu);
  intc_enable(INTC_SRC_GPIO);
  uart_rx_irq_start();
  csr_set(mie, MIE_MEIE | MIE_MTIE);
  irq_global_enable();
  update_leds();

  xprintf("\n=== RISC-V RV32IMC SoC on DE2 (Cyclone II EP2C35) ===\n");
  help();
  for (;;) {
    xprintf("> ");
    switch (read_cmd()) {
      case 'h': help(); break;
      case 'i': cmd_info(); break;
      case 's': xprintf("SW[15:0] = 0x%04x\n", gpio_read() & 0xFFFFu); break;
      case 'b': cmd_bench(); break;
      case 'f': cmd_flash(); break;
      case 'q': xprintf("bye\n"); uart_flush(); exit(0);
      default:  xprintf("?\n"); help(); break;
    }
  }
}
