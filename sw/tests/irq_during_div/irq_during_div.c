// irq_during_div.c - timer interrupts arrive at varying distances while the
// iterative divider is running. The interrupt waits until the DIV reaches MEM
// (take_irq needs a valid MEM instruction), then cancels it (mepc = DIV);
// the DIV is executed again after MRET. All results are compared with a
// software (shift-subtract) reference. The TB counts interrupts that became
// pending while the divider was busy (irq_wait_div) and interrupts that
// cancelled a DIV/REM at MEM (irq_cancel_div).
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "timer.h"
#include "testlib.h"

void div4(int32_t a, int32_t b, int32_t *res);
extern char div_window_start[], div_window_end[];

static volatile uint32_t n_irq, n_in_window;

void irq_timer_handler(void) {
  uint32_t epc = csr_read(mepc);
  n_irq++;
  if (epc >= (uint32_t)(uintptr_t)div_window_start && epc <= (uint32_t)(uintptr_t)div_window_end)
    n_in_window++;
  // next interrupt 200..499 cycles later (longer than the ISR itself), varying phase
  timer_set_cmp(timer_mtime() + 200 + (n_irq * 37) % 300);
}

static uint32_t udiv_ref(uint32_t n, uint32_t d, uint32_t *rem) {
  uint32_t q = 0, r = 0;
  for (int i = 31; i >= 0; i--) {
    r = (r << 1) | ((n >> i) & 1u);
    if (r >= d) { r -= d; q |= 1u << i; }
  }
  *rem = r;
  return q;
}

static void ref(int32_t a, int32_t b, int32_t out[4]) {
  uint32_t r, ur;
  if (b == 0) { out[0] = -1; out[1] = a; out[2] = -1; out[3] = a; return; }
  out[2] = (int32_t)udiv_ref((uint32_t)a, (uint32_t)b, &ur);
  out[3] = (int32_t)ur;
  if (a == INT32_MIN && b == -1) { out[0] = INT32_MIN; out[1] = 0; return; }
  uint32_t ua = a < 0 ? -(uint32_t)a : (uint32_t)a, ub = b < 0 ? -(uint32_t)b : (uint32_t)b;
  uint32_t q = udiv_ref(ua, ub, &r);
  out[0] = ((a < 0) != (b < 0)) ? -(int32_t)q : (int32_t)q;
  out[1] = a < 0 ? -(int32_t)r : (int32_t)r;
}

int main(void) {
  static const int32_t A[8] = {1000000007, -123456789, 0x7FFFFFFF, INT32_MIN, 42, -1, 99991, 0x12345678};
  static const int32_t B[8] = {97, 13, -3, -1, 0, 7, -31337, 0x1234};
  int32_t res[4], exp[4];
  int bad = 0;
  xprintf("irq_during_div\n");
  timer_set_cmp(timer_mtime() + 50);
  timer_irq_enable();
  irq_global_enable();
  for (int i = 0; i < 400; i++) {
    int32_t a = A[i & 7] ^ (i * 0x9E3779B1), b = B[(i >> 3) & 7] + (i & 1);
    div4(a, b, res);
    ref(a, b, exp);
    for (int k = 0; k < 4; k++) if (res[k] != exp[k]) bad++;
  }
  irq_global_disable();
  timer_irq_disable();
  T_CHECK(bad == 0, "%d wrong results", bad);
  T_CHECK(n_irq > 100, "only %u interrupts", n_irq);
  T_CHECK(n_in_window > 10, "only %u interrupts inside the division window", n_in_window);
  xprintf("1600 divisions ok=%d, interrupts=%s, in div window=%s\n", bad == 0,
          n_irq > 100 ? "many" : "few", n_in_window > 10 ? "yes" : "no");
  return t_result("irq_during_div");
}
