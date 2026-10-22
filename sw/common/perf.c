// perf.c - performance counter snapshot / report (mhpmcounter3..10).
#include "perf.h"
#include "xprintf.h"

void perf_snapshot(perf_snapshot_t *p) {
  p->cycles         = rd_mcycle();
  p->instret        = rd_minstret();
  p->branch         = READ_CSR64(mhpmcounter3, mhpmcounter3h);
  p->branch_miss    = READ_CSR64(mhpmcounter4, mhpmcounter4h);
  p->jump           = READ_CSR64(mhpmcounter5, mhpmcounter5h);
  p->jump_miss      = READ_CSR64(mhpmcounter6, mhpmcounter6h);
  p->stall_load_use = READ_CSR64(mhpmcounter7, mhpmcounter7h);
  p->stall_muldiv   = READ_CSR64(mhpmcounter8, mhpmcounter8h);
  p->stall_bus      = READ_CSR64(mhpmcounter9, mhpmcounter9h);
  p->compressed     = READ_CSR64(mhpmcounter10, mhpmcounter10h);
}

void perf_print(const char *name, const perf_snapshot_t *s, const perf_snapshot_t *e) {
  uint32_t cyc  = (uint32_t)(e->cycles - s->cycles);
  uint32_t ins  = (uint32_t)(e->instret - s->instret);
  uint32_t br   = (uint32_t)(e->branch - s->branch);
  uint32_t brm  = (uint32_t)(e->branch_miss - s->branch_miss);
  uint32_t jp   = (uint32_t)(e->jump - s->jump);
  uint32_t jpm  = (uint32_t)(e->jump_miss - s->jump_miss);
  uint32_t lu   = (uint32_t)(e->stall_load_use - s->stall_load_use);
  uint32_t md   = (uint32_t)(e->stall_muldiv - s->stall_muldiv);
  uint32_t bus  = (uint32_t)(e->stall_bus - s->stall_bus);
  uint32_t cmp  = (uint32_t)(e->compressed - s->compressed);
  uint32_t cpi  = ins ? (uint32_t)(((uint64_t)cyc * 1000u) / ins) : 0;
  uint32_t ctl  = br + jp;
  uint32_t acc  = ctl ? (uint32_t)(((uint64_t)(ctl - brm - jpm) * 1000u) / ctl) : 1000;
  xprintf("[bench] name=%s cycles=%u instret=%u cpi_x1000=%u\n", name, cyc, ins, cpi);
  xprintf("[bench] branch=%u branch_miss=%u jump=%u jump_miss=%u acc_x1000=%u\n",
          br, brm, jp, jpm, acc);
  xprintf("[bench] stall_load_use=%u stall_muldiv=%u stall_bus=%u compressed=%u\n",
          lu, md, bus, cmp);
}
