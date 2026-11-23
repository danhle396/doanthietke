// ============================================================================
// soc_top.sv - RISC-V RV32IMC SoC top level.
//   rv_core (or rv_core_sc when CORE_SC = 1), 128 KB ram_dp, dbus_xbar,
//   apb_bridge and APB slaves:
//     slot 0 UART, 1 SPI, 2 TIMER64, 3 GPIO, 4 INTC, 15 SIM_CTRL
//   Buses: Wishbone B4 classic between the core, the RAM ports, dbus_xbar
//   and apb_bridge; AMBA APB4 between apb_bridge and the peripherals.
//
// Ports: clock/reset, UART, SPI master, 16-bit GPIO (tri-state outside).
// Parameters: ENABLE_M, ENABLE_C, BP_MODE, BHT_ENTRIES, BTB_ENTRIES, CORE_SC,
//             RAM_DEPTH (32-bit words, default 32768 = 128 KB), RAM_SYNC
// ============================================================================
module soc_top #(
  parameter bit ENABLE_M    = 1'b1,
  parameter bit ENABLE_C    = 1'b1,
  parameter int BP_MODE     = 2,
  parameter int BHT_ENTRIES = 256,
  parameter int BTB_ENTRIES = 32,
  parameter bit CORE_SC     = 1'b0,
  parameter int RAM_DEPTH   = 32768,  // words (32768 = 128 KB); smaller for FPGA builds
  parameter bit RAM_SYNC    = 1'b0    // 1: falling-edge block-RAM implementation (FPGA)
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
  output logic [15:0] gpio_oe,
  // observation only (board display, fpga/board/board_display.sv): existing
  // nets brought out, no logic added; leave unconnected elsewhere
  output logic [31:0] dbg_fetch_adr,  // instruction bus address
  output logic        dbg_fetch,      // instruction bus acknowledge (one fetch)
  output logic [2:0]  dbg_irq         // {meip, msip, mtip} interrupt lines
);

  localparam logic [15:0] SLOT_MASK = 16'h801F;  // slots 0-4 and 15

  logic rst_sn;

  rst_sync u_rst (.clk, .rst_n_in(rst_n), .rst_n_out(rst_sn));

  // ---------------- Core ----------------
  // Wishbone B4 classic buses: ibus (core -> RAM instruction port),
  // dbus (core -> dbus_xbar -> RAM data port / apb_bridge).
  logic        ibus_cyc, ibus_stb, ibus_ack, ibus_err;
  logic [31:0] ibus_adr, ibus_dat;
  logic        dbus_cyc, dbus_stb, dbus_we, dbus_ack, dbus_err;
  logic [3:0]  dbus_sel;
  logic [31:0] dbus_adr, dbus_wdat, dbus_rdat;
  logic        irq_mtip, irq_msip, irq_meip;
  logic [63:0] mtime;

  generate
  if (CORE_SC) begin : g_sc
    rv_core_sc u_core (
      .clk, .rst_n(rst_sn),
      .ibus_cyc_o(ibus_cyc), .ibus_stb_o(ibus_stb), .ibus_adr_o(ibus_adr),
      .ibus_dat_i(ibus_dat), .ibus_ack_i(ibus_ack), .ibus_err_i(ibus_err),
      .dbus_cyc_o(dbus_cyc), .dbus_stb_o(dbus_stb), .dbus_we_o(dbus_we), .dbus_sel_o(dbus_sel),
      .dbus_adr_o(dbus_adr), .dbus_dat_o(dbus_wdat), .dbus_dat_i(dbus_rdat),
      .dbus_ack_i(dbus_ack), .dbus_err_i(dbus_err),
      .irq_mtip, .irq_msip, .irq_meip, .mtime
    );
  end else begin : g_pipe
    rv_core #(
      .ENABLE_M(ENABLE_M), .ENABLE_C(ENABLE_C), .BP_MODE(BP_MODE),
      .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES)
    ) u_core (
      .clk, .rst_n(rst_sn),
      .ibus_cyc_o(ibus_cyc), .ibus_stb_o(ibus_stb), .ibus_adr_o(ibus_adr),
      .ibus_dat_i(ibus_dat), .ibus_ack_i(ibus_ack), .ibus_err_i(ibus_err),
      .dbus_cyc_o(dbus_cyc), .dbus_stb_o(dbus_stb), .dbus_we_o(dbus_we), .dbus_sel_o(dbus_sel),
      .dbus_adr_o(dbus_adr), .dbus_dat_o(dbus_wdat), .dbus_dat_i(dbus_rdat),
      .dbus_ack_i(dbus_ack), .dbus_err_i(dbus_err),
      .irq_mtip, .irq_msip, .irq_meip, .mtime
    );
  end
  endgenerate

  // ---------------- Memory & bus ----------------
  logic        ram_cyc, ram_stb, ram_we, ram_ack;
  logic [3:0]  ram_sel;
  logic [31:0] ram_adr, ram_wdat, ram_rdat;
  logic        br_cyc, br_stb, br_we, br_ack, br_err;
  logic [3:0]  br_sel;
  logic [31:0] br_adr, br_wdat, br_rdat;

  assign dbg_fetch_adr = ibus_adr;
  assign dbg_fetch     = ibus_cyc & ibus_stb & ibus_ack;
  assign dbg_irq       = {irq_meip, irq_msip, irq_mtip};

  ram_dp #(.DEPTH(RAM_DEPTH), .SYNC(RAM_SYNC)) u_ram (
    .clk,
    .wbi_cyc_i(ibus_cyc), .wbi_stb_i(ibus_stb), .wbi_adr_i(ibus_adr),
    .wbi_dat_o(ibus_dat), .wbi_ack_o(ibus_ack), .wbi_err_o(ibus_err),
    .wbd_cyc_i(ram_cyc), .wbd_stb_i(ram_stb), .wbd_we_i(ram_we), .wbd_sel_i(ram_sel),
    .wbd_adr_i(ram_adr), .wbd_dat_i(ram_wdat), .wbd_dat_o(ram_rdat), .wbd_ack_o(ram_ack)
  );

  dbus_xbar #(.RAM_SIZE(RAM_DEPTH * 4)) u_xbar (
    .m_cyc_i(dbus_cyc), .m_stb_i(dbus_stb), .m_we_i(dbus_we), .m_sel_i(dbus_sel),
    .m_adr_i(dbus_adr), .m_dat_i(dbus_wdat), .m_dat_o(dbus_rdat),
    .m_ack_o(dbus_ack), .m_err_o(dbus_err),
    .ram_cyc_o(ram_cyc), .ram_stb_o(ram_stb), .ram_we_o(ram_we), .ram_sel_o(ram_sel),
    .ram_adr_o(ram_adr), .ram_dat_o(ram_wdat), .ram_dat_i(ram_rdat), .ram_ack_i(ram_ack),
    .apb_cyc_o(br_cyc), .apb_stb_o(br_stb), .apb_we_o(br_we), .apb_sel_o(br_sel),
    .apb_adr_o(br_adr), .apb_dat_o(br_wdat), .apb_dat_i(br_rdat),
    .apb_ack_i(br_ack), .apb_err_i(br_err)
  );

  logic [31:0] paddr, pwdata, prdata;
  logic [15:0] psel;
  logic        penable, pwrite, pready, pslverr;
  logic [3:0]  pstrb, slot;
  logic [2:0]  pprot;

  apb_bridge #(.SLOT_MASK(SLOT_MASK)) u_apb (
    .clk, .rst_n(rst_sn),
    .wb_cyc_i(br_cyc), .wb_stb_i(br_stb), .wb_we_i(br_we), .wb_sel_i(br_sel),
    .wb_adr_i(br_adr), .wb_dat_i(br_wdat), .wb_dat_o(br_rdat),
    .wb_ack_o(br_ack), .wb_err_o(br_err),
    .paddr, .psel, .penable, .pwrite, .pwdata, .pstrb, .pprot,
    .prdata, .pready, .pslverr, .slot
  );

  // ---------------- APB slaves ----------------
  logic [31:0] uart_prdata, spi_prdata, tmr_prdata, gpio_prdata, intc_prdata, sim_prdata;
  logic        uart_pready, spi_pready, tmr_pready, gpio_pready, intc_pready, sim_pready;
  logic        uart_pslverr, spi_pslverr, tmr_pslverr, gpio_pslverr, intc_pslverr, sim_pslverr;
  logic        uart_irq, spi_irq, gpio_irq;

  uart_apb u_uart (
    .clk, .rst_n(rst_sn),
    .psel(psel[0]), .penable, .pwrite, .paddr(paddr[11:0]), .pwdata, .pstrb,
    .prdata(uart_prdata), .pready(uart_pready), .pslverr(uart_pslverr),
    .uart_tx, .uart_rx, .irq(uart_irq)
  );

  spi_apb u_spi (
    .clk, .rst_n(rst_sn),
    .psel(psel[1]), .penable, .pwrite, .paddr(paddr[11:0]), .pwdata, .pstrb,
    .prdata(spi_prdata), .pready(spi_pready), .pslverr(spi_pslverr),
    .spi_sclk, .spi_mosi, .spi_miso, .spi_cs_n, .irq(spi_irq)
  );

  timer64_apb u_timer (
    .clk, .rst_n(rst_sn),
    .psel(psel[2]), .penable, .pwrite, .paddr(paddr[11:0]), .pwdata, .pstrb,
    .prdata(tmr_prdata), .pready(tmr_pready), .pslverr(tmr_pslverr),
    .mtime, .mtip(irq_mtip), .msip(irq_msip)
  );

  gpio_apb u_gpio (
    .clk, .rst_n(rst_sn),
    .psel(psel[3]), .penable, .pwrite, .paddr(paddr[11:0]), .pwdata, .pstrb,
    .prdata(gpio_prdata), .pready(gpio_pready), .pslverr(gpio_pslverr),
    .gpio_i, .gpio_o, .gpio_oe, .irq(gpio_irq)
  );

  intc_apb #(.N_SRC(3)) u_intc (
    .clk, .rst_n(rst_sn),
    .psel(psel[4]), .penable, .pwrite, .paddr(paddr[11:0]), .pwdata, .pstrb,
    .prdata(intc_prdata), .pready(intc_pready), .pslverr(intc_pslverr),
    .src({gpio_irq, spi_irq, uart_irq}), .irq(irq_meip)
  );

  sim_ctrl u_sim (
    .clk, .rst_n(rst_sn),
    .psel(psel[15]), .penable, .pwrite, .paddr(paddr[11:0]), .pwdata, .pstrb,
    .prdata(sim_prdata), .pready(sim_pready), .pslverr(sim_pslverr)
  );

  // response mux (slot of the current transfer)
  always_comb begin
    case (slot)
      4'd0:    begin prdata = uart_prdata; pready = uart_pready; pslverr = uart_pslverr; end
      4'd1:    begin prdata = spi_prdata;  pready = spi_pready;  pslverr = spi_pslverr;  end
      4'd2:    begin prdata = tmr_prdata;  pready = tmr_pready;  pslverr = tmr_pslverr;  end
      4'd3:    begin prdata = gpio_prdata; pready = gpio_pready; pslverr = gpio_pslverr; end
      4'd4:    begin prdata = intc_prdata; pready = intc_pready; pslverr = intc_pslverr; end
      4'd15:   begin prdata = sim_prdata;  pready = sim_pready;  pslverr = sim_pslverr;  end
      default: begin prdata = 32'b0;       pready = 1'b1;        pslverr = 1'b1;         end
    endcase
  end

  /* verilator lint_off UNUSEDSIGNAL */
  // pprot is fixed to 0; upper PADDR bits are decoded by the bridge;
  // PSEL of empty slots is never asserted.
  logic unused;
  assign unused = ^{pprot, paddr[31:12], psel[14:5]};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
