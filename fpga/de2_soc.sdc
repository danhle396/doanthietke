# de2_soc.sdc - timing constraints (TimeQuest) for de2_top.
# The PLL output clock (24 MHz) is derived from CLOCK_50. The RAM banks are
# clocked on the falling edge, so TimeQuest checks the half-cycle paths
# (register -> RAM address and RAM data -> register) automatically.

create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_pll_clocks
derive_clock_uncertainty

# JTAG console (jtag_uart_bridge): the virtual JTAG logic runs on the
# USB-Blaster TCK (clock altera_reserved_tck, created by Quartus itself).
# Every TCK <-> CPU clock crossing is a synchronized single bit or data held
# stable by a handshake, so the two clocks are unrelated.
set_clock_groups -asynchronous -group [get_clocks {altera_reserved_tck}]

# Asynchronous board I/O: switches and keys (synchronized inside the SoC),
# UART RX (oversampled), SPI pins (SCLK is at most CPU clock / 4), LEDs and
# 7-segment digits.
set_false_path -from [get_ports {KEY[*] SW[*] UART_RXD GPIO_0[*]}]
set_false_path -to   [get_ports {LEDR[*] LEDG[*] HEX*[*] UART_TXD GPIO_0[*]}]
