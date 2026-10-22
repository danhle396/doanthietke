// bench_rt.c - runtime glue for riscv-tests benchmarks: setStats() measures
// the region of interest with mcycle/minstret/mhpmcounter3..10 and prints it.
#include <stdarg.h>
#include "perf.h"
#include "xprintf.h"

#ifndef BENCH_NAME
#define BENCH_NAME "bench"
#endif

static perf_snapshot_t start_snap;

void setStats(int enable) {
  if (enable) {
    perf_snapshot(&start_snap);
  } else {
    perf_snapshot_t end_snap;
    perf_snapshot(&end_snap);
    perf_print(BENCH_NAME, &start_snap, &end_snap);
  }
}

int printf(const char *fmt, ...) {
  va_list ap;
  va_start(ap, fmt);
  int n = xvprintf(fmt, ap);
  va_end(ap);
  return n;
}

int sprintf(char *buf, const char *fmt, ...) {
  // only used for short strings by the benchmarks
  va_list ap;
  va_start(ap, fmt);
  int n = xvsprintf(buf, fmt, ap);
  va_end(ap);
  return n;
}

int putchar(int c) {
  xputc((char)c);
  return c;
}
