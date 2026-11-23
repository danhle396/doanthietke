// ============================================================================
// de2_top.sv - Top level for the Terasic DE2 board (Cyclone II EP2C35F672C6).
//   CLOCK_50 -> PLL -> 24 MHz CPU clock (UART 115200 baud: BAUD_DIV = 12).
//   KEY[0]     : reset (active low; the board debounces the keys)
//   KEY[3:1]   : console commands for a demo without PC (key_cmd.sv):
//                KEY1 "b" benchmark, KEY2 "t" self-test, KEY3 "f" flash ID
//   SW[15:0]   : gpio_i[15:0]
//   SW[17:16]  : display mode of HEX7..HEX0 (board_display.sv):
//                00 result (PASS/FAIL, benchmark cycles)  01 PC
//                10 instruction fetches per second        11 UART characters
//   LEDR[15:0] : gpio_o[15:0] (bits configured as outputs)
//   LEDR[16]   : SPI chip select active    LEDR[17] : test printed FAIL
//   LEDG[0]    : PLL locked                LEDG[1]  : SoC running (reset released)
//   LEDG[2]    : UART transmitting         LEDG[3]  : SoC held in reset by the host
//   LEDG[4]    : JTAG console active       LEDG[5]  : timer interrupt
//   LEDG[6]    : external interrupt (INTC) LEDG[7]  : test printed PASS
//   LEDG[8]    : heartbeat (CPU clock / 2^24, ~1.4 Hz)
//   HEX7..HEX0 : see SW[17:16]
//   UART_TXD/RXD : RS-232 connector (through the board's level shifter)
//   JTAG console : the same UART also goes over the USB-Blaster cable through
//                  jtag_uart_bridge (sld_virtual_jtag); host side
//                  fpga/tools/jtag_uart.py (terminal and automatic board tests)
//   GPIO_0[0..6] (header JP1 pins 1..7): SPI SCLK, MOSI, MISO, CS0_n..CS3_n
//   SoC: rv_core RV32IMC, BP_MODE 2, 32 KB RAM in M4K blocks (RAM_SYNC = 1).
// ============================================================================
module de2_top (
  input  logic        CLOCK_50,
  input  logic [3:0]  KEY,
  input  logic [17:0] SW,
  output logic [17:0] LEDR,
  output logic [8:0]  LEDG,
  output logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
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

  // ---------------- JTAG console (UART over the USB-Blaster cable) ----------------
  logic       uart_tx, uart_rx, jb_rx, host_rst, host_act;
  logic [7:0] tx_byte;
  logic       tx_byte_valid;
  logic       vj_tck, vj_tdi, vj_tdo, vj_cdr, vj_sdr, vj_udr;
  logic [1:0] vj_ir;

  sld_virtual_jtag #(
    .sld_auto_instance_index("YES"),
    .sld_instance_index     (0),
    .sld_ir_width           (2),
    .sld_sim_action         (""),
    .sld_sim_n_scan         (0),
    .sld_sim_total_length   (0),
    .lpm_type               ("sld_virtual_jtag")
  ) u_vjtag (
    .tck              (vj_tck),
    .tdi              (vj_tdi),
    .tdo              (vj_tdo),
    .ir_in            (vj_ir),
    .ir_out           (2'b00),
    .virtual_state_cdr(vj_cdr),
    .virtual_state_sdr(vj_sdr),
    .virtual_state_udr(vj_udr)
  );

  jtag_uart_bridge u_jbridge (
    .clk        (clk),
    .rst_n      (pll_locked),
    .tck        (vj_tck),
    .tdi        (vj_tdi),
    .tdo        (vj_tdo),
    .sel        (vj_ir == 2'd1),
    .cdr        (vj_cdr),
    .sdr        (vj_sdr),
    .udr        (vj_udr),
    .uart_tx    (uart_tx),
    .uart_rx    (jb_rx),
    .cpu_rst_req(host_rst),
    .tx_byte    (tx_byte),
    .tx_byte_valid(tx_byte_valid),
    .host_act   (host_act)
  );

  // ---------------- push buttons as console commands ----------------
  logic key_rx;

  key_cmd u_keys (
    .clk  (clk),
    .rst_n(pll_locked),
    .key_n(KEY[3:1]),
    .tx   (key_rx)
  );

  assign UART_TXD = uart_tx;
  assign uart_rx  = UART_RXD & jb_rx & key_rx;   // all idle high

  assign rst_n = KEY[0] & pll_locked & ~host_rst;

  logic        spi_sclk, spi_mosi;
  logic [3:0]  spi_cs_n;
  logic [15:0] gpio_o, gpio_oe;
  logic [31:0] dbg_fetch_adr;
  logic        dbg_fetch;
  logic [2:0]  dbg_irq;

  soc_top #(
    .ENABLE_M(1'b1), .ENABLE_C(1'b1), .BP_MODE(2), .BHT_ENTRIES(256), .BTB_ENTRIES(32),
    .CORE_SC(1'b0), .RAM_DEPTH(8192), .RAM_SYNC(1'b1)
  ) u_soc (
    .clk     (clk),
    .rst_n   (rst_n),
    .uart_tx (uart_tx),
    .uart_rx (uart_rx),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(GPIO_0[2]),
    .spi_cs_n(spi_cs_n),
    .gpio_i  (SW[15:0]),
    .gpio_o  (gpio_o),
    .gpio_oe (gpio_oe),
    .dbg_fetch_adr(dbg_fetch_adr),
    .dbg_fetch    (dbg_fetch),
    .dbg_irq      (dbg_irq)
  );

  // SPI on the expansion header (GPIO_0[2] is an input with a weak pull-up)
  assign GPIO_0[0]   = spi_sclk;
  assign GPIO_0[1]   = spi_mosi;
  assign GPIO_0[2]   = 1'bz;
  assign GPIO_0[6:3] = spi_cs_n;

  // ---------------- 7-segment display and status LEDs ----------------
  logic led_tx, led_host, led_mtip, led_meip, led_spi, led_pass, led_fail;

  board_display #(.CLK_HZ(24_000_000)) u_disp (
    .clk          (clk),
    .rst_n        (pll_locked),
    .soc_rst_n    (rst_n),
    .mode         (SW[17:16]),
    .tx_byte      (tx_byte),
    .tx_byte_valid(tx_byte_valid),
    .uart_tx      (uart_tx),
    .fetch_adr    (dbg_fetch_adr),
    .fetch        (dbg_fetch),
    .irq          (dbg_irq),
    .spi_cs_n     (spi_cs_n),
    .host_act     (host_act),
    .hex0(HEX0), .hex1(HEX1), .hex2(HEX2), .hex3(HEX3),
    .hex4(HEX4), .hex5(HEX5), .hex6(HEX6), .hex7(HEX7),
    .led_tx(led_tx), .led_host(led_host), .led_mtip(led_mtip), .led_meip(led_meip),
    .led_spi(led_spi), .led_pass(led_pass), .led_fail(led_fail)
  );

  assign LEDR = {led_fail, led_spi, gpio_o & gpio_oe};

  logic [23:0] hb_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) hb_q <= 24'd0;
    else        hb_q <= hb_q + 24'd1;
  end
  assign LEDG = {hb_q[23], led_pass, led_meip, led_mtip, led_host, host_rst, led_tx, rst_n,
                 pll_locked};

endmodule
