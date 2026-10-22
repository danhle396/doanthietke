// branch_smc.c - control-flow corner cases:
//  1. trap on the first correct-path instruction after a mispredicted branch
//     (taken BEQ to an ECALL with a cold BTB);
//  2. self-modifying code + FENCE.I: a JAL that the BTB has learned is replaced
//     by an ADDI; after FENCE.I the BTB still predicts "taken" for the ADDI
//     (BTB alias) - the core must detect it at EX, redirect to pc+4 and drop
//     the stale entry; the result must reflect the new code.
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "testlib.h"

void branch_to_ecall(void);
extern char branch_ecall_insn[];
extern volatile uint32_t smc_buf[3];

static volatile uint32_t t_cause, t_epc, n_traps;

void exception_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval) {
  (void)mtval;
  t_cause = mcause;
  t_epc = mepc;
  n_traps++;
  csr_write(mepc, mepc + 4);
}

typedef uint32_t (*fn_t)(uint32_t);

int main(void) {
  xprintf("branch_smc\n");
  // ---- 1. trap right after a mispredicted branch ----
  branch_to_ecall();
  T_CHECK(n_traps == 1 && t_cause == 11, "trap count %u cause %u", n_traps, t_cause);
  T_CHECK(t_epc == (uint32_t)(uintptr_t)branch_ecall_insn, "mepc %x", t_epc);
  xprintf("trap after mispredicted branch: mcause=%u mepc=%s\n", t_cause,
          t_epc == (uint32_t)(uintptr_t)branch_ecall_insn ? "ok" : "BAD");

  // ---- 2. self-modifying code ----
  fn_t f = (fn_t)(uintptr_t)smc_buf;
  __asm__ volatile ("fence.i" ::: "memory");
  uint32_t r1 = f(0), r2 = f(0);           // JAL skips the ADDI 100 (BTB learns the JAL)
  smc_buf[0] = 0x00150513u;                // addi a0, a0, 1
  __asm__ volatile ("fence.i" ::: "memory");
  uint32_t r3 = f(0), r4 = f(5);           // new code: +1 then +100
  T_CHECK(r1 == 0 && r2 == 0, "before patch: %u %u", r1, r2);
  T_CHECK(r3 == 101 && r4 == 106, "after patch: %u %u", r3, r4);
  xprintf("self-modifying code: before=%u,%u after=%u,%u\n", r1, r2, r3, r4);
  return t_result("branch_smc");
}
