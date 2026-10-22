// timer_irq.c - N periodic machine-timer interrupts. The ISR re-arms
// mtimecmp += PERIOD; the interrupt time (mtime read in the ISR) must follow
// mtimecmp by less than MAX_LAT cycles and consecutive interrupts must be
// PERIOD apart (within the latency jitter).
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "timer.h"
#include "testlib.h"

#define PERIOD  3000u
#define N       8
#define MAX_LAT 200u

static volatile int      count;
static volatile uint64_t cmp_val;
static uint64_t          t_irq[N], t_cmp[N];

void irq_timer_handler(void) {
  uint64_t now = timer_mtime();
  if (count < N) {
    t_irq[count] = now;
    t_cmp[count] = cmp_val;
  }
  count++;
  if (count >= N) {
    timer_irq_disable();
    timer_set_cmp(~0ull);
  } else {
    cmp_val += PERIOD;
    timer_set_cmp(cmp_val);
  }
}

int main(void) {
  xprintf("timer_irq\n");
  timer_config(1, 0);
  cmp_val = timer_mtime() + PERIOD;
  timer_set_cmp(cmp_val);
  timer_irq_enable();
  irq_global_enable();
  while (count < N) __asm__ volatile ("wfi");
  irq_global_disable();

  uint32_t max_lat = 0;
  for (int i = 0; i < N; i++) {
    uint32_t lat = (uint32_t)(t_irq[i] - t_cmp[i]);
    if (lat > max_lat) max_lat = lat;
    T_CHECK(t_irq[i] >= t_cmp[i] && lat < MAX_LAT, "irq %d latency %u", i, lat);
    if (i > 0) {
      uint32_t d = (uint32_t)(t_irq[i] - t_irq[i - 1]);
      T_CHECK(d > PERIOD - MAX_LAT && d < PERIOD + MAX_LAT, "interval %d = %u", i, d);
      T_CHECK(t_cmp[i] - t_cmp[i - 1] == PERIOD, "mtimecmp step");
    }
  }
  T_CHECK(count == N, "count %d", count);
  xprintf("%d interrupts, period %u, max latency %u cycles\n", N, PERIOD, max_lat);
  return t_result("timer_irq");
}
