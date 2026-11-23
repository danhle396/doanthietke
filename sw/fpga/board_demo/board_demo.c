// board_demo.c - Interactive demo for the DE2 board (UART 115200 8N1).
//   LEDR[7:0]  mirror SW[7:0], updated by the GPIO edge interrupt
//   LEDR[15:8] seconds counter, updated by the machine-timer interrupt
//   UART commands (one per line, RX interrupt + ring buffer):
//     h help, i info, s switches, b benchmark (perf counters),
//     t self-test (prints RESULT selftest: PASS/FAIL),
//     f SPI flash JEDEC ID (W25Q module on GPIO_0), q quit
//   On the board KEY1 / KEY2 / KEY3 type "b", "t", "f" (fpga/board/key_cmd.sv)
//   and the 7-segment display shows the result (fpga/board/board_display.sv).
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
#include "testlib.h"

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

// ---- self-test: every check has a fixed expected value -------------------
#define RTYPE(name)                                                       \
  static uint32_t i_##name(uint32_t a, uint32_t b) {                      \
    uint32_t r;                                                           \
    __asm__ volatile (#name " %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));    \
    return r;                                                             \
  }
RTYPE(mul) RTYPE(mulh) RTYPE(mulhsu) RTYPE(mulhu)
RTYPE(div) RTYPE(divu) RTYPE(rem) RTYPE(remu)

static volatile uint32_t va = 0x12345678u, vb = 0x9ABCDEF0u, vc = 0x87654321u, vd = 0x00012345u;
static volatile uint64_t vn = 7593366ull * 1000u, vq = 6753600u;

static void cmd_selftest(void) {
  tl_errors = 0;
  tl_checks = 0;
  // RV32M: expected values computed independently (Python big integers)
  T_CHECK(i_mul(va, vb) == 0x242D2080u, "mul");
  T_CHECK(i_mulh(va, vb) == 0xF8CC93D6u, "mulh");
  T_CHECK(i_mulhsu(va, vb) == 0x0B00EA4Eu, "mulhsu");
  T_CHECK(i_mulhu(va, vb) == 0x0B00EA4Eu, "mulhu");
  T_CHECK(i_div(vc, vd) == 0xFFFF9600u, "div");
  T_CHECK(i_rem(vc, vd) == 0xFFFFD521u, "rem");
  T_CHECK(i_divu(vc, vd) == 0x00007700u, "divu");
  T_CHECK(i_remu(vc, vd) == 0x00003021u, "remu");
  T_CHECK(vn / vq == 1124u && vn % vq == 2319600u, "64-bit division");
  xprintf("RV32M    : %s\n", tl_errors ? "FAIL" : "ok");
  // RAM: two complementary patterns over a 4 KB buffer
  int e0 = tl_errors;
  for (int pass = 0; pass < 2; pass++) {
    uint32_t inv = pass ? 0xFFFFFFFFu : 0u;
    for (int i = 0; i < N_WORDS; i++) buf[i] = ((uint32_t)i * 0x9E3779B9u) ^ inv;
    int bad = 0;
    for (int i = 0; i < N_WORDS; i++) bad += buf[i] != (((uint32_t)i * 0x9E3779B9u) ^ inv);
    T_CHECK(bad == 0, "RAM pattern %d: %d words wrong", pass, bad);
  }
  xprintf("RAM      : %s\n", tl_errors != e0 ? "FAIL" : "ok");
  // CSR, timer against the cycle counter. (The benchmark workload is not
  // called here: a second caller would stop it being inlined into cmd_bench
  // and change the benchmark's code and cycle count.)
  e0 = tl_errors;
  T_CHECK(csr_read(misa) == 0x40001104u, "misa");
  uint64_t t0 = timer_mtime();
  uint32_t c0 = (uint32_t)rd_mcycle();
  while ((uint32_t)rd_mcycle() - c0 < 48000u) ;      // 2 ms at 24 MHz
  uint32_t dt = (uint32_t)(timer_mtime() - t0);       // microseconds
  T_CHECK(dt >= 1990u && dt <= 2010u, "timer: %u us in 2 ms", dt);
  xprintf("CSR/timer: %s\n", tl_errors != e0 ? "FAIL" : "ok");
  (void)t_result("selftest");
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
  xprintf("commands: h help | i info | s switches | b benchmark | t self-test | f flash ID | "
          "q quit\n");
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
      case 't': cmd_selftest(); break;
      case 'f': cmd_flash(); break;
      case 'q': xprintf("bye\n"); uart_flush(); exit(0);
      default:  xprintf("?\n"); help(); break;
    }
  }
}
