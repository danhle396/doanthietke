// hello.c - prints a greeting on the console (UART or SIM_CTRL) and exits 0.
#include "xprintf.h"
#include "sys.h"

int main(void) {
  xprintf("Hello from RV32IMC SoC!\n");
  xprintf("dec=%d neg=%d hex=%08x str=%s chr=%c pct=%%\n", 12345, -42, 0xBEEFu, "ok", 'Z');
  return 0;
}
