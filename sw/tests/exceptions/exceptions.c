// exceptions.c - synchronous exceptions taken by a C trap handler, which
// records mcause/mepc/mtval and resumes after the faulting instruction:
// illegal, ecall, ebreak, load/store misaligned, load/store access fault
// (unmapped address and empty APB slot -> PSLVERR), instruction access fault,
// and (without the C extension) instruction-address-misaligned.
#include <stdint.h>
#include "platform.h"
#include "csr.h"
#include "sys.h"
#include "testlib.h"

void do_illegal(void); void do_ecall(void); void do_ebreak(void);
void do_ill_miscmem(void); void do_ill_sret(void); void do_ill_sys4(void);
uint32_t do_csr_noexist(void); void do_csr_ro_write(uint32_t v);
void do_load_mis(uint32_t a); void do_load_mis_h(uint32_t a); void do_store_mis(uint32_t a);
void do_load_fault(uint32_t a); void do_store_fault(uint32_t a);
void do_fetch_fault(uint32_t a); void do_jump_misaligned(uint32_t a);
extern char misaligned_target[];

volatile uint32_t fetch_ret;
static volatile uint32_t t_cause, t_epc, t_tval, n_traps;
static volatile uint32_t buf[4];

void exception_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval) {
  t_cause = mcause; t_epc = mepc; t_tval = mtval;
  n_traps++;
  if (mcause == CAUSE_FETCH_ACCESS) {
    csr_write(mepc, fetch_ret);
  } else {
    uint16_t h = *(volatile uint16_t *)mepc;
    csr_write(mepc, mepc + (((h & 3u) == 3u) ? 4u : 2u));
  }
}

static void expect(const char *name, uint32_t cause, uint32_t epc, uint32_t tval, uint32_t n0) {
  T_CHECK(n_traps == n0 + 1, "%s: %d traps", name, (int)(n_traps - n0));
  T_CHECK(t_cause == cause, "%s: mcause %u exp %u", name, t_cause, cause);
  T_CHECK(t_epc == epc, "%s: mepc %x exp %x", name, t_epc, epc);
  T_CHECK(t_tval == tval, "%s: mtval %x exp %x", name, t_tval, tval);
  xprintf("%s: mcause=%u mepc=%s mtval=%x\n", name, t_cause, t_epc == epc ? "ok" : "BAD", t_tval);
}

#define A(f) ((uint32_t)(uintptr_t)&(f))

int main(void) {
  uint32_t n0, mis = A(buf[1]) + 1;
  xprintf("exceptions\n");
  n0 = n_traps; do_illegal();           expect("illegal", 2, A(do_illegal), 0xFFFFFFFFu, n0);
  n0 = n_traps; do_ill_miscmem();       expect("illegal misc-mem", 2, A(do_ill_miscmem), 0x0000200Fu, n0);
  n0 = n_traps; do_ill_sret();          expect("illegal sret", 2, A(do_ill_sret), 0x10200073u, n0);
  n0 = n_traps; do_ill_sys4();          expect("illegal system f3=4", 2, A(do_ill_sys4), 0x00004073u, n0);
  n0 = n_traps; (void)do_csr_noexist(); expect("csr not existing", 2, A(do_csr_noexist), 0x7C002573u, n0);
  n0 = n_traps; do_csr_ro_write(5);     expect("csr read-only write", 2, A(do_csr_ro_write), 0xC0051073u, n0);
  {  // mcycle is writable: the next read continues from the written value
    csr_write(mcycle, 1000);
    uint32_t c = csr_read(mcycle);
    T_CHECK(c >= 1000 && c < 1100, "mcycle after write: %u", c);
    xprintf("mcycle write: ok\n");
  }
  n0 = n_traps; do_ecall();             expect("ecall", 11, A(do_ecall), 0, n0);
  n0 = n_traps; do_ebreak();            expect("ebreak", 3, A(do_ebreak), A(do_ebreak), n0);
  n0 = n_traps; do_load_mis(mis);       expect("load misaligned", 4, A(do_load_mis), mis, n0);
  n0 = n_traps; do_load_mis_h(mis + 2); expect("lh misaligned", 4, A(do_load_mis_h), mis + 2, n0);
  n0 = n_traps; do_store_mis(mis + 1);  expect("store misaligned", 6, A(do_store_mis), mis + 1, n0);
  n0 = n_traps; do_load_fault(0x0);     expect("load access fault", 5, A(do_load_fault), 0x0, n0);
  n0 = n_traps; do_store_fault(0x20000000u);
  expect("store access fault", 7, A(do_store_fault), 0x20000000u, n0);
  n0 = n_traps; do_load_fault(0x10005000u);
  expect("apb empty slot", 5, A(do_load_fault), 0x10005000u, n0);
  n0 = n_traps; do_fetch_fault(0x00001000u);
  expect("fetch access fault", 1, 0x00001000u, 0x00001000u, n0);
#ifdef __riscv_compressed
  xprintf("jump misaligned: n/a (C enabled)\n");
#else
  n0 = n_traps; do_jump_misaligned(A(misaligned_target));
  expect("jump misaligned", 0, A(do_jump_misaligned), A(misaligned_target), n0);
#endif
  // the stores that trapped must not have modified memory
  T_CHECK(buf[1] == 0 && buf[2] == 0, "faulting store wrote memory");
  return t_result("exceptions");
}
