// ============================================================================
// soc_top.sv - RISC-V RV32IMC SoC top level.
//   rv_core (or rv_core_sc when CORE_SC = 1), 128 KB ram_dp, dbus_xbar,
//   apb_bridge and APB slaves:
//     slot 0 UART, 1 SPI, 2 TIMER64, 3 GPIO, 4 INTC, 15 SIM_CTRL
//
// Ports: clock/reset, UART, SPI master, 16-bit GPIO (tri-state outside).
// Parameters: ENABLE_M, ENABLE_C, BP_MODE, BHT_ENTRIES, BTB_ENTRIES, CORE_SC
// ============================================================================
module soc_top #(
  parameter bit ENABLE_M    = 1'b1,
  parameter bit ENABLE_C    = 1'b1,
  parameter int BP_MODE     = 2,
  parameter int BHT_ENTRIES = 256,
  parameter int BTB_ENTRIES = 32,
  parameter bit CORE_SC     = 1'b0
) (
  input  logic        clk,
  input  logic        rst_n,
  output logic        uart_tx,
  input  logic        uart_rx,
  output logic        spi_sclk,
  output logic        spi_mosi,
  input  logic        spi_miso,
  output logic [3:0]  spi_cs_n,
  input  logic [15:0] gpio_i,
  output logic [15:0] gpio_o,
  output logic [15:0] gpio_oe
);

  localparam logic [15:0] SLOT_MASK = 16'h8000;

  logic rst_sn;

  rst_sync u_rst (.clk, .rst_n_in(rst_n), .rst_n_out(rst_sn));

  // ---------------- Core ----------------
  logic [31:0] ibus_addr, ibus_rdata;
  logic        ibus_err;
  logic        dbus_req, dbus_we, dbus_ready, dbus_err;
  logic [3:0]  dbus_be;
  logic [31:0] dbus_addr, dbus_wdata, dbus_rdata;
  logic        irq_mtip, irq_msip, irq_meip;
  logic [63:0] mtime;

  if (CORE_SC) begin : g_sc
    rv_core_sc u_core (
      .clk, .rst_n(rst_sn),
      .ibus_addr, .ibus_rdata, .ibus_err,
      .dbus_req, .dbus_we, .dbus_be, .dbus_addr, .dbus_wdata,
      .dbus_ready, .dbus_err, .dbus_rdata,
      .irq_mtip, .irq_msip, .irq_meip, .mtime
    );
  end else begin : g_pipe
    rv_core #(
      .ENABLE_M(ENABLE_M), .ENABLE_C(ENABLE_C), .BP_MODE(BP_MODE),
      .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES)
    ) u_core (
      .clk, .rst_n(rst_sn),
      .ibus_addr, .ibus_rdata, .ibus_err,
      .dbus_req, .dbus_we, .dbus_be, .dbus_addr, .dbus_wdata,
      .dbus_ready, .dbus_err, .dbus_rdata,
      .irq_mtip, .irq_msip, .irq_meip, .mtime
    );
  end

  // ---------------- Memory & bus ----------------
  logic        ram_req, ram_we, ram_ready;
  logic [3:0]  ram_be;
  logic [31:0] ram_addr, ram_wdata, ram_rdata;
  logic        br_req, br_we, br_ready, br_err;
  logic [3:0]  br_be;
  logic [31:0] br_addr, br_wdata, br_rdata;

  ram_dp u_ram (
    .clk,
    .i_addr (ibus_addr), .i_rdata(ibus_rdata), .i_err(ibus_err),
    .d_req  (ram_req), .d_we(ram_we), .d_be(ram_be), .d_addr(ram_addr),
    .d_wdata(ram_wdata), .d_rdata(ram_rdata), .d_ready(ram_ready)
  );

  dbus_xbar u_xbar (
    .c_req(dbus_req), .c_we(dbus_we), .c_be(dbus_be), .c_addr(dbus_addr),
    .c_wdata(dbus_wdata), .c_ready(dbus_ready), .c_err(dbus_err), .c_rdata(dbus_rdata),
    .ram_req, .ram_we, .ram_be, .ram_addr, .ram_wdata, .ram_ready, .ram_rdata,
    .apb_req(br_req), .apb_we(br_we), .apb_be(br_be), .apb_addr(br_addr),
    .apb_wdata(br_wdata), .apb_ready(br_ready), .apb_err(br_err), .apb_rdata(br_rdata)
  );

  logic [31:0] paddr, pwdata, prdata;
  logic [15:0] psel;
  logic        penable, pwrite, pready, pslverr;
  logic [3:0]  pstrb, slot;
  logic [2:0]  pprot;

  apb_bridge #(.SLOT_MASK(SLOT_MASK)) u_apb (
    .clk, .rst_n(rst_sn),
    .s_req(br_req), .s_we(br_we), .s_be(br_be), .s_addr(br_addr), .s_wdata(br_wdata),
    .s_ready(br_ready), .s_err(br_err), .s_rdata(br_rdata),
    .paddr, .psel, .penable, .pwrite, .pwdata, .pstrb, .pprot,
    .prdata, .pready, .pslverr, .slot
  );

  // ---------------- APB slaves ----------------
  logic [31:0] sim_prdata;
  logic        sim_pready, sim_pslverr;

  sim_ctrl u_sim (
    .clk, .rst_n(rst_sn),
    .psel(psel[15]), .penable, .pwrite, .paddr(paddr[11:0]), .pwdata, .pstrb,
    .prdata(sim_prdata), .pready(sim_pready), .pslverr(sim_pslverr)
  );

  always_comb begin
    case (slot)
      4'd15:   begin prdata = sim_prdata; pready = sim_pready; pslverr = sim_pslverr; end
      default: begin prdata = 32'b0;      pready = 1'b1;       pslverr = 1'b1;        end
    endcase
  end

  // ---------------- Interrupts / unused I/O (peripherals added later) ----
  assign irq_mtip = 1'b0;
  assign irq_msip = 1'b0;
  assign irq_meip = 1'b0;
  assign mtime    = 64'b0;
  assign uart_tx  = 1'b1;
  assign spi_sclk = 1'b0;
  assign spi_mosi = 1'b0;
  assign spi_cs_n = 4'hF;
  assign gpio_o   = 16'b0;
  assign gpio_oe  = 16'b0;

  /* verilator lint_off UNUSEDSIGNAL */
  logic unused;
  assign unused = ^{uart_rx, spi_miso, gpio_i, pprot, paddr[31:12], psel[14:0]};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
