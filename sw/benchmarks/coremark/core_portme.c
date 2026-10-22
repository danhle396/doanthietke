// core_portme.c - CoreMark porting layer: mcycle for timing, xprintf for
// output, performance counters printed for the timed region.
#include <stdarg.h>
#include "coremark.h"
#include "core_portme.h"
#include "perf.h"
#include "xprintf.h"

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

#define EE_TICKS_PER_SEC 50000000u   // mcycle at 50 MHz

static perf_snapshot_t t_start, t_stop;
ee_u32 default_num_contexts = 1;

void start_time(void) { perf_snapshot(&t_start); }
void stop_time(void)  { perf_snapshot(&t_stop); }

CORE_TICKS get_time(void) { return (CORE_TICKS)(t_stop.cycles - t_start.cycles); }

secs_ret time_in_secs(CORE_TICKS ticks) { return (secs_ret)(ticks / EE_TICKS_PER_SEC); }

void portable_init(core_portable *p, int *argc, char *argv[]) {
  (void)argc; (void)argv;
  p->portable_id = 1;
}

void portable_fini(core_portable *p) {
  p->portable_id = 0;
  perf_print("coremark", &t_start, &t_stop);
}

int ee_printf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int n = xvprintf(fmt, ap);
  va_end(ap);
  return n;
}
