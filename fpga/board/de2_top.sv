// ============================================================================
// de2_top.sv - Top level for the Terasic DE2 board (Cyclone II EP2C35F672C6).
//   CLOCK_50 -> PLL -> 24 MHz CPU clock (UART 115200 baud: BAUD_DIV = 12).
//   KEY[0]     : reset (active low; the board debounces the keys)
//   SW[15:0]   : gpio_i[15:0]
//   LEDR[15:0] : gpio_o[15:0] (bits configured as outputs)
//   LEDG[0]    : PLL locked       LEDG[1] : reset released
//   LEDG[2]    : UART TX activity LEDG[8] : heartbeat (CPU clock / 2^24, ~1.4 Hz)
//   UART_TXD/RXD : RS-232 connector (through the board's level shifter)
//   GPIO_0[0..6] (header JP1 pins 1..7): SPI SCLK, MOSI, MISO, CS0_n..CS3_n
//   SoC: rv_core RV32IMC, BP_MODE 2, 32 KB RAM in M4K blocks (RAM_SYNC = 1).
// ============================================================================
module de2_top (
  input  logic        CLOCK_50,
  input  logic [3:0]  KEY,
  input  logic [17:0] SW,
  output logic [17:0] LEDR,
  output logic [8:0]  LEDG,
  output logic        UART_TXD,
  input  logic        UART_RXD,
  inout  wire  [6:0]  GPIO_0
);

  logic clk, pll_locked, rst_n;

  pll_cpu u_pll (
    .inclk0(CLOCK_50),
    .c0    (clk),
    .locked(pll_locked)
  );

  assign rst_n = KEY[0] & pll_locked;

  logic        spi_sclk, spi_mosi;
  logic [3:0]  spi_cs_n;
  logic [15:0] gpio_o, gpio_oe;

  soc_top #(
    .ENABLE_M(1'b1), .ENABLE_C(1'b1), .BP_MODE(2), .BHT_ENTRIES(256), .BTB_ENTRIES(32),
    .CORE_SC(1'b0), .RAM_DEPTH(8192), .RAM_SYNC(1'b1)
  ) u_soc (
    .clk     (clk),
    .rst_n   (rst_n),
    .uart_tx (UART_TXD),
    .uart_rx (UART_RXD),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(GPIO_0[2]),
    .spi_cs_n(spi_cs_n),
    .gpio_i  (SW[15:0]),
    .gpio_o  (gpio_o),
    .gpio_oe (gpio_oe)
  );

  // SPI on the expansion header (GPIO_0[2] is an input with a weak pull-up)
  assign GPIO_0[0]   = spi_sclk;
  assign GPIO_0[1]   = spi_mosi;
  assign GPIO_0[2]   = 1'bz;
  assign GPIO_0[6:3] = spi_cs_n;

  assign LEDR = {2'b00, gpio_o & gpio_oe};

  // status LEDs
  logic [23:0] hb_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) hb_q <= 24'd0;
    else        hb_q <= hb_q + 24'd1;
  end
  assign LEDG = {hb_q[23], 5'b00000, ~UART_TXD, rst_n, pll_locked};

  /* verilator lint_off UNUSEDSIGNAL */
  logic unused;
  assign unused = ^{KEY[3:1], SW[17:16]};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
