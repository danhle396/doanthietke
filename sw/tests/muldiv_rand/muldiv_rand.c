// muldiv_rand.c - RV32M instructions (MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM,
// REMU, issued by inline assembly) and 64-bit division (libgcc __udivdi3 /
// __umoddi3) on corner and random operands, against reference models that
// use only add, subtract and shift. Added after the DE2 board showed MULH*
// returning copies of the sign bit: a synthesis tool can disagree with the
// simulator, so the board runs this test too (fpga/firmware/muldiv_rand).
#include <stdint.h>
#include "platform.h"
#include "sys.h"
#include "testlib.h"

#define N_RAND 1200

// ------------------------------------------------------------ references
static uint64_t ref_mulu(uint32_t a, uint32_t b) {
  uint32_t lo = 0, hi = 0, ah = 0, al = a;
  for (int i = 0; i < 32; i++) {
    if ((b >> i) & 1u) {
      uint32_t nlo = lo + al;
      hi += ah + (nlo < lo);
      lo = nlo;
    }
    ah = (ah << 1) | (al >> 31);
    al <<= 1;
  }
  return ((uint64_t)hi << 32) | lo;
}

static uint64_t ref_divmod64(uint64_t n, uint64_t d, uint64_t *rem) {
  uint64_t q = 0, r = 0;
  for (int i = 63; i >= 0; i--) {
    r = (r << 1) | ((n >> i) & 1u);
    if (r >= d) { r -= d; q |= (uint64_t)1 << i; }
  }
  *rem = r;
  return q;
}

static uint32_t ref_divu(uint32_t a, uint32_t b, uint32_t *rem) {
  if (b == 0) { *rem = a; return 0xFFFFFFFFu; }
  uint64_t r, q = ref_divmod64(a, b, &r);
  *rem = (uint32_t)r;
  return (uint32_t)q;
}

static uint32_t ref_div(uint32_t a, uint32_t b, uint32_t *rem) {
  if (b == 0) { *rem = a; return 0xFFFFFFFFu; }
  if (a == 0x80000000u && b == 0xFFFFFFFFu) { *rem = 0; return a; }
  uint32_t ua = (a >> 31) ? (0u - a) : a, ub = (b >> 31) ? (0u - b) : b, ur;
  uint32_t uq = ref_divu(ua, ub, &ur);
  *rem = (a >> 31) ? (0u - ur) : ur;
  return ((a ^ b) >> 31) ? (0u - uq) : uq;
}

// --------------------------------------------------------- instructions
#define RTYPE(name)                                                       \
  static uint32_t i_##name(uint32_t a, uint32_t b) {                      \
    uint32_t r;                                                           \
    __asm__ volatile (#name " %0, %1, %2" : "=r"(r) : "r"(a), "r"(b));    \
    return r;                                                             \
  }
RTYPE(mul) RTYPE(mulh) RTYPE(mulhsu) RTYPE(mulhu)
RTYPE(div) RTYPE(divu) RTYPE(rem) RTYPE(remu)

enum { OP_MUL, OP_MULH, OP_MULHSU, OP_MULHU, OP_DIV, OP_DIVU, OP_REM, OP_REMU, OP_DIV64, N_OP };
static const char *const op_name[N_OP] = {"mul", "mulh", "mulhsu", "mulhu", "div", "divu",
                                          "rem", "remu", "div64"};
static int op_err[N_OP];

static void report(int op, uint32_t a, uint32_t b, uint32_t got, uint32_t exp) {
  if (op_err[op]++ < 3)
    xprintf("  %s a=%08x b=%08x -> %08x, expected %08x\n", op_name[op], a, b, got, exp);
}

static void check_pair(uint32_t a, uint32_t b) {
  uint64_t pu = ref_mulu(a, b);
  uint32_t hu = (uint32_t)(pu >> 32);
  uint32_t hs = hu - ((a >> 31) ? b : 0u) - ((b >> 31) ? a : 0u);   // signed x signed
  uint32_t hsu = hu - ((a >> 31) ? b : 0u);                          // signed x unsigned
  uint32_t r, e, er;
  if ((r = i_mul(a, b)) != (uint32_t)pu) report(OP_MUL, a, b, r, (uint32_t)pu);
  if ((r = i_mulh(a, b)) != hs) report(OP_MULH, a, b, r, hs);
  if ((r = i_mulhsu(a, b)) != hsu) report(OP_MULHSU, a, b, r, hsu);
  if ((r = i_mulhu(a, b)) != hu) report(OP_MULHU, a, b, r, hu);
  e = ref_div(a, b, &er);
  if ((r = i_div(a, b)) != e) report(OP_DIV, a, b, r, e);
  if ((r = i_rem(a, b)) != er) report(OP_REM, a, b, r, er);
  e = ref_divu(a, b, &er);
  if ((r = i_divu(a, b)) != e) report(OP_DIVU, a, b, r, e);
  if ((r = i_remu(a, b)) != er) report(OP_REMU, a, b, r, er);
}

static volatile uint64_t vn, vd;

static void check_div64(uint64_t n, uint64_t d) {
  uint64_t r, q = ref_divmod64(n, d, &r);
  vn = n; vd = d;
  uint64_t gq = vn / vd, gr = vn % vd;
  if (gq != q || gr != r) {
    if (op_err[OP_DIV64]++ < 3)
      xprintf("  div64 %08x%08x / %08x%08x -> q=%08x%08x r=%08x%08x, expected q=%08x%08x r=%08x%08x\n",
              (uint32_t)(n >> 32), (uint32_t)n, (uint32_t)(d >> 32), (uint32_t)d,
              (uint32_t)(gq >> 32), (uint32_t)gq, (uint32_t)(gr >> 32), (uint32_t)gr,
              (uint32_t)(q >> 32), (uint32_t)q, (uint32_t)(r >> 32), (uint32_t)r);
  }
}

static uint32_t s = 0x2545F491u;
static uint32_t rnd(void) { s ^= s << 13; s ^= s >> 17; s ^= s << 5; return s; }

int main(void) {
  static const uint32_t corner[] = {0u, 1u, 2u, 3u, 7u, 0x7FFFFFFFu, 0x80000000u, 0x80000001u,
                                    0xFFFFFFFFu, 0xFFFFFFFEu, 0x0000FFFFu, 0x00010000u,
                                    0x55555555u, 0xAAAAAAAAu};
  const int nc = (int)(sizeof corner / sizeof corner[0]);
  xprintf("muldiv_rand\n");
  for (int i = 0; i < nc; i++)
    for (int j = 0; j < nc; j++) check_pair(corner[i], corner[j]);
  for (int i = 0; i < N_RAND; i++) {
    uint32_t a = rnd(), b = rnd(), c = rnd();
    if (c & 1u) b >>= (c >> 1) & 31u;       // small divisors too
    if (c & 2u) a >>= (c >> 6) & 31u;
    check_pair(a, b);
    uint64_t n = ((uint64_t)a << 32) | rnd(), d;
    switch (c >> 28) {
      case 0: case 1: case 2: d = rnd(); break;                        // 64 / 32
      case 3: d = (uint64_t)rnd() << 32 | rnd(); break;                // 64 / 64
      case 4: d = rnd() >> (c & 31u); break;                           // small
      case 5: n = (uint64_t)(a >> 4) * 1000u; d = (b >> 4) | 1u; break; // CPI x 1000
      default: n >>= (c & 63u); d = (uint64_t)(rnd() | 1u) << (c & 31u); break;
    }
    if (d == 0) d = 1;
    check_div64(n, d);
  }
  // the board case that exposed the fault: mcycle * 1000 / minstret
  check_div64((uint64_t)7593366u * 1000u, 6753600u);
  for (int k = 0; k < N_OP; k++) {
    xprintf("%-6s : %s\n", op_name[k], op_err[k] ? "FAIL" : "ok");
    T_CHECK(op_err[k] == 0, "%s: %d wrong results", op_name[k], op_err[k]);
  }
  return t_result("muldiv_rand");
}
