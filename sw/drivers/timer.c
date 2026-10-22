// timer.c - TIMER64 driver.
#include "timer.h"
#include "platform.h"
#include "csr.h"

uint64_t timer_mtime(void) {
  uint32_t hi, lo, hi2;
  do {
    hi  = REG32(TIMER_MTIME_HI);
    lo  = REG32(TIMER_MTIME_LO);
    hi2 = REG32(TIMER_MTIME_HI);
  } while (hi != hi2);
  return ((uint64_t)hi << 32) | lo;
}

void timer_set_mtime(uint64_t v) {
  REG32(TIMER_MTIME_LO) = 0;                  // avoid a carry between the writes
  REG32(TIMER_MTIME_HI) = (uint32_t)(v >> 32);
  REG32(TIMER_MTIME_LO) = (uint32_t)v;
}

// Privileged spec sequence: no spurious interrupt while the two halves change.
void timer_set_cmp(uint64_t v) {
  REG32(TIMER_MTIMECMP_LO) = 0xFFFFFFFFu;
  REG32(TIMER_MTIMECMP_HI) = (uint32_t)(v >> 32);
  REG32(TIMER_MTIMECMP_LO) = (uint32_t)v;
}

uint64_t timer_get_cmp(void) {
  return ((uint64_t)REG32(TIMER_MTIMECMP_HI) << 32) | REG32(TIMER_MTIMECMP_LO);
}

void timer_config(int enable, uint32_t prescale) {
  REG32(TIMER_CTRL) = (enable ? 1u : 0u) | ((prescale & 0xFFu) << 8);
}

void timer_msip(int set) { REG32(TIMER_MSIP) = set ? 1u : 0u; }

void timer_irq_enable(void)  { csr_set(mie, MIE_MTIE); }
void timer_irq_disable(void) { csr_clear(mie, MIE_MTIE); }
