// perf.h - 64-bit counter reads (hi-lo-hi loop) and a perf report printer.
#ifndef PERF_H
#define PERF_H

#include <stdint.h>
#include "csr.h"

#define READ_CSR64(lo, hi) ({ uint32_t __h, __l, __h2;            \
    do { __h = csr_read(hi); __l = csr_read(lo); __h2 = csr_read(hi); \
    } while (__h != __h2);                                          \
    ((uint64_t)__h << 32) | __l; })

static inline uint64_t rd_mcycle(void)   { return READ_CSR64(mcycle, mcycleh); }
static inline uint64_t rd_minstret(void) { return READ_CSR64(minstret, minstreth); }

typedef struct {
  uint64_t cycles, instret;
  uint64_t branch, branch_miss, jump, jump_miss;
  uint64_t stall_load_use, stall_muldiv, stall_bus, compressed;
} perf_snapshot_t;

void perf_snapshot(perf_snapshot_t *p);
void perf_print(const char *name, const perf_snapshot_t *start, const perf_snapshot_t *end);

#endif
