// util.h - replacement for riscv-tests/benchmarks/common/util.h on this SoC:
// single hart, no HTIF; setStats() snapshots the performance counters.
#ifndef __UTIL_H
#define __UTIL_H

#include <stdint.h>

extern void setStats(int enable);

#define static_assert(cond) switch(0) { case 0: case !!(long)(cond): ; }

#define read_csr(reg) ({ unsigned long __tmp; \
  __asm__ volatile ("csrr %0, " #reg : "=r"(__tmp)); __tmp; })
#define write_csr(reg, val) ({ \
  __asm__ volatile ("csrw " #reg ", %0" :: "rK"(val)); })

static int verify(int n, const volatile int* test, const int* verify)
{
  int i;
  for (i = 0; i < n/2*2; i+=2)
  {
    int t0 = test[i], t1 = test[i+1];
    int v0 = verify[i], v1 = verify[i+1];
    if (t0 != v0) return i+1;
    if (t1 != v1) return i+2;
  }
  if (n % 2 != 0 && test[n-1] != verify[n-1])
    return n;
  return 0;
}

#endif
