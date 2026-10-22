// spi_modes.c - SPI master vs. spi_slave_bfm (CS1, echo mode) in all four
// modes x MSB/LSB first x two clock dividers. The slave returns 0xA5 first and
// then (previous byte received ^ 0x5A), so both MOSI and MISO are checked.
#include <stdint.h>
#include "platform.h"
#include "spi.h"
#include "testlib.h"

#define N 8

int main(void) {
  uint8_t tx[N], rx[N];
  xprintf("spi_modes\n");
  for (int div = 0; div < 2; div++) {
    for (int mode = 0; mode < 4; mode++) {
      for (int lsb = 0; lsb < 2; lsb++) {
        spi_init(div ? 4u : 0u, (uint32_t)mode, lsb);
        for (int i = 0; i < N; i++) tx[i] = (uint8_t)(mode * 16 + lsb * 8 + i * 37 + div * 101);
        spi_select(1);
        spi_xfer_buf(tx, rx, N);
        spi_deselect();
        int bad = 0;
        if (rx[0] != 0xA5) bad++;
        for (int i = 1; i < N; i++) if (rx[i] != (uint8_t)(tx[i - 1] ^ 0x5A)) bad++;
        T_CHECK(bad == 0, "div %d mode %d lsb %d: %d bad bytes (rx0=%02x rx1=%02x)", div, mode,
                lsb, bad, rx[0], rx[1]);
        xprintf("div=%d mode=%d %s: %s\n", div ? 4 : 0, mode, lsb ? "lsb" : "msb",
                bad ? "FAIL" : "ok");
      }
    }
  }
  return t_result("spi_modes");
}
