// testlib.h - minimal self-checking helpers for firmware tests.
#ifndef TESTLIB_H
#define TESTLIB_H

#include "xprintf.h"

static int tl_errors = 0;
static int tl_checks = 0;

#define T_CHECK(cond, ...) do {                                   \
    tl_checks++;                                                  \
    if (!(cond)) {                                                \
      tl_errors++;                                                \
      xprintf("CHECK FAILED line %d: ", __LINE__);                \
      xprintf(__VA_ARGS__);                                       \
      xprintf("\n");                                              \
    }                                                             \
  } while (0)

// Prints the final RESULT line; the return value is the exit code.
static inline int t_result(const char *name) {
  xprintf("RESULT %s: %s (%d checks, %d errors)\n", name, tl_errors ? "FAIL" : "PASS",
          tl_checks, tl_errors);
  return tl_errors ? 1 : 0;
}

static inline void delay_cycles(uint32_t n) {
  uint32_t t0;
  __asm__ volatile ("csrr %0, mcycle" : "=r"(t0));
  for (;;) {
    uint32_t t;
    __asm__ volatile ("csrr %0, mcycle" : "=r"(t));
    if (t - t0 >= n) break;
  }
}

#endif
