// irq_priority.c - MEI, MSI and MTI made pending together while MIE = 0;
// enabling MIE must serve them in the order MEI > MSI > MTI. Run with mtvec
// in direct mode and in vectored mode (the vectored slot used is recorded by
// the stub in vectors.S and must equal the interrupt cause).
//   MEI source: UART TX_WM (TX FIFO empty, level 0 <= TX_WM_LVL 0)
//   MSI source: TIMER.MSIP = 1        MTI source: mtimecmp = 0
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "timer.h"
#include "intc.h"
#include "uart.h"
#include "testlib.h"

extern void prio_vector_table(void);
static volatile uint32_t order[8], slot[8];
static volatile int n_irq;

void trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval) {
  (void)mepc; (void)mtval;
  if (n_irq < 8) {
    order[n_irq] = mcause;
    slot[n_irq] = csr_read(mscratch);
  }
  n_irq++;
  switch (mcause) {
    case MCAUSE_MEI: REG32(UART_IRQ_EN) = 0; break;
    case MCAUSE_MSI: timer_msip(0); break;
    case MCAUSE_MTI: timer_set_cmp(~0ull); break;
    default: exit(0x100 + (int)mcause);
  }
}

static void run(int vectored) {
  n_irq = 0;
  csr_write(mscratch, 0xFF);
  if (vectored) csr_write(mtvec, (uint32_t)(uintptr_t)&prio_vector_table | 1u);
  else          set_mtvec_direct();
  // make all three pending (TX_WM needs an empty TX FIFO: flush the console)
  uart_flush();
  REG32(UART_WATERMARK) = 0;
  REG32(UART_IRQ_EN) = UART_IRQ_TX_WM;
  intc_enable(INTC_SRC_UART);
  timer_msip(1);
  timer_set_cmp(0);
  csr_write(mie, MIE_MEIE | MIE_MSIE | MIE_MTIE);
  uint32_t mip = csr_read(mip);
  T_CHECK((mip & 0x888u) == 0x888u, "mip %x", mip);
  irq_global_enable();
  __asm__ volatile ("nop; nop; nop; nop");
  irq_global_disable();
  T_CHECK(n_irq == 3, "%d interrupts", n_irq);
  T_CHECK(order[0] == MCAUSE_MEI && order[1] == MCAUSE_MSI && order[2] == MCAUSE_MTI,
          "order %x %x %x", order[0], order[1], order[2]);
  if (vectored)
    T_CHECK(slot[0] == 11 && slot[1] == 3 && slot[2] == 7, "slots %d %d %d", slot[0], slot[1], slot[2]);
  else
    T_CHECK(slot[0] == 0xFF && slot[1] == 0xFF && slot[2] == 0xFF, "direct mode used a vector slot");
  xprintf("%s: order", vectored ? "vectored" : "direct");
  for (int i = 0; i < n_irq && i < 3; i++)
    xprintf(" %s", order[i] == MCAUSE_MEI ? "MEI" : order[i] == MCAUSE_MSI ? "MSI" : "MTI");
  if (vectored) xprintf(" slots %d %d %d", slot[0], slot[1], slot[2]);
  xprintf("\n");
  csr_write(mie, 0);
  intc_disable(INTC_SRC_UART);
}

int main(void) {
  xprintf("irq_priority\n");
  run(0);
  run(1);
  set_mtvec_direct();
  return t_result("irq_priority");
}
