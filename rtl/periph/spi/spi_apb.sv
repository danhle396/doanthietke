module spi_apb #(
  parameter int FIFO_DEPTH = 16
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [11:0] paddr,
  input  logic [31:0] pwdata,
  input  logic [3:0]  pstrb,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,
  output logic        spi_sclk,
  output logic        spi_mosi,
  input  logic        spi_miso,
  output logic [3:0]  spi_cs_n,
  output logic        irq
);

  localparam int LW = $clog2(FIFO_DEPTH) + 1;

  localparam logic [11:0] A_DATA = 12'h00, A_STATUS = 12'h04, A_CTRL = 12'h08,
                          A_DIV  = 12'h0C, A_CS = 12'h10, A_IRQ_EN = 12'h14,
                          A_IRQ_ST = 12'h18;

  // ---------------- APB decode ----------------
  logic valid_off, wr, rd;
  assign valid_off = (paddr == A_DATA) || (paddr == A_STATUS) || (paddr == A_CTRL) ||
                     (paddr == A_DIV) || (paddr == A_CS) || (paddr == A_IRQ_EN) ||
                     (paddr == A_IRQ_ST);
  assign wr      = psel && penable && pwrite && valid_off;
  assign rd      = psel && penable && !pwrite && valid_off;
  assign pready  = 1'b1;
  assign pslverr = psel && penable && !valid_off;

  function automatic logic [31:0] merge(input logic [31:0] old, input logic [31:0] nw,
                                        input logic [3:0] strb);
    merge = old;
    for (int b = 0; b < 4; b++) if (strb[b]) merge[b*8 +: 8] = nw[b*8 +: 8];
  endfunction

  // ---------------- Registers ----------------
  logic [3:0]  ctrl_q, cs_q, irq_en_q;
  logic [15:0] div_q;
  logic        done_q, overrun_q;

  /* verilator lint_off UNUSEDSIGNAL */
  // Full-width merged write values; only the implemented bits are stored.
  logic [31:0] ctrl_w, div_w, cs_w, irq_en_w;
  /* verilator lint_on UNUSEDSIGNAL */
  assign ctrl_w   = merge({28'b0, ctrl_q}, pwdata, pstrb);
  assign div_w    = merge({16'b0, div_q}, pwdata, pstrb);
  assign cs_w     = merge({28'b0, cs_q}, pwdata, pstrb);
  assign irq_en_w = merge({28'b0, irq_en_q}, pwdata, pstrb);

  // ---------------- FIFOs + engine ----------------
  logic          tx_push, tx_pop, tx_full, tx_empty;
  logic [7:0]    tx_rdata;
  logic [LW-1:0] tx_level;
  logic          rx_push, rx_pop, rx_full, rx_empty;
  logic [7:0]    rx_rdata;
  logic [LW-1:0] rx_level;
  logic          eng_rx_valid, eng_busy, eng_last;
  logic [7:0]    eng_rx_data;

  assign tx_push = wr && (paddr == A_DATA) && pstrb[0];
  assign rx_pop  = rd && (paddr == A_DATA) && !rx_empty;
  assign rx_push = eng_rx_valid && !rx_full;

  sync_fifo #(.WIDTH(8), .DEPTH(FIFO_DEPTH)) u_txf (
    .clk, .rst_n, .push(tx_push), .wdata(pwdata[7:0]), .pop(tx_pop), .rdata(tx_rdata),
    .full(tx_full), .empty(tx_empty), .level(tx_level));

  sync_fifo #(.WIDTH(8), .DEPTH(FIFO_DEPTH)) u_rxf (
    .clk, .rst_n, .push(rx_push), .wdata(eng_rx_data), .pop(rx_pop), .rdata(rx_rdata),
    .full(rx_full), .empty(rx_empty), .level(rx_level));

  spi_master u_eng (
    .clk, .rst_n, .en(ctrl_q[0]), .cpol(ctrl_q[1]), .cpha(ctrl_q[2]), .lsb_first(ctrl_q[3]),
    .clk_div(div_q), .tx_valid(!tx_empty), .tx_data(tx_rdata), .tx_pop(tx_pop),
    .rx_valid(eng_rx_valid), .rx_data(eng_rx_data), .busy(eng_busy), .last(eng_last),
    .sclk(spi_sclk), .mosi(spi_mosi), .miso(spi_miso));

  // ---------------- Status / interrupts ----------------
  logic clr_done, clr_ovr, ev_done, ev_ovr;
  assign clr_done = wr && (paddr == A_IRQ_ST) && pstrb[0] && pwdata[2];
  assign clr_ovr  = wr && (paddr == A_IRQ_ST) && pstrb[0] && pwdata[3];
  assign ev_done  = eng_rx_valid && eng_last;
  assign ev_ovr   = eng_rx_valid && rx_full;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_q    <= 4'h0;
      div_q     <= 16'd3;
      cs_q      <= 4'hF;
      irq_en_q  <= 4'h0;
      done_q    <= 1'b0;
      overrun_q <= 1'b0;
    end else begin
      if (wr && paddr == A_CTRL)   ctrl_q   <= ctrl_w[3:0];
      if (wr && paddr == A_DIV)    div_q    <= div_w[15:0];
      if (wr && paddr == A_CS)     cs_q     <= cs_w[3:0];
      if (wr && paddr == A_IRQ_EN) irq_en_q <= irq_en_w[3:0];
      done_q    <= ev_done || (done_q && !clr_done);
      overrun_q <= ev_ovr  || (overrun_q && !clr_ovr);
    end
  end

  logic [3:0] irq_st;
  assign irq_st   = {overrun_q, done_q, !rx_empty, tx_empty};
  assign irq      = |(irq_st & irq_en_q);
  assign spi_cs_n = cs_q;

  always_comb begin
    case (paddr)
      A_DATA:   prdata = {rx_empty, 23'b0, rx_rdata};
      A_STATUS: prdata = {11'b0, 5'(rx_level), 3'b0, 5'(tx_level), 2'b0, overrun_q, eng_busy,
                          rx_full, rx_empty, tx_empty, tx_full};
      A_CTRL:   prdata = {28'b0, ctrl_q};
      A_DIV:    prdata = {16'b0, div_q};
      A_CS:     prdata = {28'b0, cs_q};
      A_IRQ_EN: prdata = {28'b0, irq_en_q};
      A_IRQ_ST: prdata = {28'b0, irq_st};
      default:  prdata = 32'b0;
    endcase
  end

endmodule
