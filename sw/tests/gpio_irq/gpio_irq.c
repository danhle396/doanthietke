// gpio_irq.c - GPIO outputs and edge interrupts.
//   Outputs: patterns written to OUT[7:0] are read back through the TB
//   loopback on IN[15:8] (synchronized).
//   Interrupts: pins 0,2 rising, pins 1,3 falling; raising OUT[15] asks the
//   TB to toggle IN[3:0] four times (initial 1010) -> every pin must see
//   exactly two enabled edges.
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "gpio.h"
#include "intc.h"
#include "testlib.h"

static volatile int per_pin[4];
static volatile int events;

void gpio_isr(void) {
  uint32_t st = gpio_irq_status();
  for (int i = 0; i < 4; i++)
    if (st & (1u << i)) { per_pin[i]++; events++; }
  gpio_irq_clear(st);
}

int main(void) {
  static const uint8_t pat[] = {0x00, 0xFF, 0xA5, 0x5A, 0x3C, 0x81};
  xprintf("gpio_irq\n");
  gpio_set_dir(0x80FFu);
  for (unsigned i = 0; i < sizeof(pat); i++) {
    gpio_write(pat[i]);
    delay_cycles(8);
    uint32_t in = gpio_read();
    T_CHECK(((in >> 8) & 0xFF) == pat[i], "loopback %02x read %08x", pat[i], in);
  }
  xprintf("output patterns ok\n");

  gpio_irq_config(0x000Fu, 0x000Au);   // pins 1,3 falling, 0,2 rising
  intc_enable(INTC_SRC_GPIO);
  csr_set(mie, MIE_MEIE);
  irq_global_enable();
  gpio_write(0x8000u);                 // request TB stimulus
  uint32_t t = 0;
  while (events < 8 && t++ < 100000) __asm__ volatile ("wfi");
  delay_cycles(2000);                  // no further events may arrive
  irq_global_disable();
  for (int i = 0; i < 4; i++) T_CHECK(per_pin[i] == 2, "pin %d events %d", i, per_pin[i]);
  T_CHECK(events == 8, "events %d", events);
  xprintf("edge events: %d %d %d %d\n", per_pin[0], per_pin[1], per_pin[2], per_pin[3]);
  return t_result("gpio_irq");
}
