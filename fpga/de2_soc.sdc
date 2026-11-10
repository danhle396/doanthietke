# de2_soc.sdc - timing constraints (TimeQuest) for de2_top.
# The PLL output clock (24 MHz) is derived from CLOCK_50. The RAM banks are
# clocked on the falling edge, so TimeQuest checks the half-cycle paths
# (register -> RAM address and RAM data -> register) automatically.

create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_pll_clocks
derive_clock_uncertainty

# Asynchronous board I/O: switches and keys (synchronized inside the SoC),
# UART RX (oversampled), SPI pins (SCLK is at most CPU clock / 4) and LEDs.
set_false_path -from [get_ports {KEY[*] SW[*] UART_RXD GPIO_0[*]}]
set_false_path -to   [get_ports {LEDR[*] LEDG[*] UART_TXD GPIO_0[*]}]
