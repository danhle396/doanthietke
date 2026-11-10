// ============================================================================
// uart_apb.sv - UART with 16-entry TX/RX FIFOs and interrupts (APB slave,
//   0x1000_0000). Register map: docs/register_map.md.
//
// Ports: APB4 slave (paddr[11:0]), uart_tx/uart_rx pins, irq (level).
// Parameters: FIFO_DEPTH (16)
// ============================================================================
module uart_apb #(
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
  output logic        uart_tx,
  input  logic        uart_rx,
  output logic        irq
);

  localparam int LW = $clog2(FIFO_DEPTH) + 1;

  localparam logic [11:0] A_DATA = 12'h00, A_STATUS = 12'h04, A_CTRL = 12'h08,
                          A_BAUD = 12'h0C, A_IRQ_EN = 12'h10, A_IRQ_ST = 12'h14,
                          A_WM   = 12'h18;

  // ---------------- APB decode ----------------
  logic valid_off, wr, rd;
  assign valid_off = (paddr == A_DATA) || (paddr == A_STATUS) || (paddr == A_CTRL) ||
                     (paddr == A_BAUD) || (paddr == A_IRQ_EN) || (paddr == A_IRQ_ST) ||
                     (paddr == A_WM);
  assign wr      = psel && penable && pwrite && valid_off;
  assign rd      = psel && penable && !pwrite && valid_off;
  assign pready  = 1'b1;
  assign pslverr = psel && penable && !valid_off;

  // ---------------- Registers ----------------
  logic [4:0]  ctrl_q;
  logic [15:0] baud_q;
  logic [2:0]  irq_en_q;
  logic [4:0]  wm_tx_q, wm_rx_q;
  logic        overrun_q, frame_q, parity_q, err_q;

  // byte-lane write helper
  function automatic logic [31:0] merge(input logic [31:0] old, input logic [31:0] nw,
                                        input logic [3:0] strb);
    merge = old;
    for (int b = 0; b < 4; b++) if (strb[b]) merge[b*8 +: 8] = nw[b*8 +: 8];
  endfunction

  /* verilator lint_off UNUSEDSIGNAL */
  // Full-width merged write values; only the implemented bits are stored.
  logic [31:0] ctrl_w, baud_w, irq_en_w, wm_w;
  /* verilator lint_on UNUSEDSIGNAL */
  assign ctrl_w   = merge({27'b0, ctrl_q}, pwdata, pstrb);
  assign baud_w   = merge({16'b0, baud_q}, pwdata, pstrb);
  assign irq_en_w = merge({29'b0, irq_en_q}, pwdata, pstrb);
  assign wm_w     = merge({11'b0, wm_rx_q, 11'b0, wm_tx_q}, pwdata, pstrb);

  // ---------------- FIFOs ----------------
  logic          tx_busy;
  logic          rx_valid, rx_ferr, rx_perr;
  logic [7:0]    rx_data;
  logic          tx_push, tx_pop, tx_full, tx_empty;
  logic [7:0]    tx_rdata;
  logic [LW-1:0] tx_level;
  logic          rx_push, rx_pop, rx_full, rx_empty;
  logic [7:0]    rx_rdata;
  logic [LW-1:0] rx_level;

  assign tx_push = wr && (paddr == A_DATA) && pstrb[0];
  assign rx_pop  = rd && (paddr == A_DATA) && !rx_empty;

  sync_fifo #(.WIDTH(8), .DEPTH(FIFO_DEPTH)) u_txf (
    .clk, .rst_n, .push(tx_push), .wdata(pwdata[7:0]), .pop(tx_pop), .rdata(tx_rdata),
    .full(tx_full), .empty(tx_empty), .level(tx_level));

  sync_fifo #(.WIDTH(8), .DEPTH(FIFO_DEPTH)) u_rxf (
    .clk, .rst_n, .push(rx_push), .wdata(rx_data), .pop(rx_pop), .rdata(rx_rdata),
    .full(rx_full), .empty(rx_empty), .level(rx_level));

  // ---------------- TX / RX engines ----------------
  uart_tx u_tx (
    .clk, .rst_n, .baud_div(baud_q), .en(ctrl_q[0]), .parity_en(ctrl_q[2]),
    .parity_odd(ctrl_q[3]), .stop2(ctrl_q[4]), .data_valid(!tx_empty), .data(tx_rdata),
    .data_pop(tx_pop), .tx(uart_tx), .busy(tx_busy));

  uart_rx u_rx (
    .clk, .rst_n, .baud_div(baud_q), .en(ctrl_q[1]), .parity_en(ctrl_q[2]),
    .parity_odd(ctrl_q[3]), .rx(uart_rx), .valid(rx_valid), .data(rx_data),
    .frame_err(rx_ferr), .parity_err(rx_perr));

  // A received byte is stored unless the RX FIFO is full (overrun: dropped).
  assign rx_push = rx_valid && !rx_full;

  // ---------------- Status / interrupts ----------------
  logic tx_wm, rx_wm, err_clr, ovr_ev, ferr_ev, perr_ev;
  assign tx_wm   = (6'(tx_level) <= 6'(wm_tx_q));
  assign rx_wm   = (6'(rx_level) >= 6'(wm_rx_q));
  assign err_clr = wr && (paddr == A_IRQ_ST) && pstrb[0] && pwdata[2];
  assign ovr_ev  = rx_valid && rx_full;
  assign ferr_ev = rx_valid && rx_ferr;
  assign perr_ev = rx_valid && rx_perr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_q    <= 5'h03;
      baud_q    <= 16'd26;
      irq_en_q  <= 3'b0;
      wm_tx_q   <= 5'd0;
      wm_rx_q   <= 5'd1;
      overrun_q <= 1'b0;
      frame_q   <= 1'b0;
      parity_q  <= 1'b0;
      err_q     <= 1'b0;
    end else begin
      if (wr && paddr == A_CTRL)   ctrl_q   <= ctrl_w[4:0];
      if (wr && paddr == A_BAUD)   baud_q   <= baud_w[15:0];
      if (wr && paddr == A_IRQ_EN) irq_en_q <= irq_en_w[2:0];
      if (wr && paddr == A_WM) begin
        wm_tx_q <= wm_w[4:0];
        wm_rx_q <= wm_w[20:16];
      end
      // sticky error flags: a new event in the same cycle wins over W1C
      overrun_q <= ovr_ev  || (overrun_q && !err_clr);
      frame_q   <= ferr_ev || (frame_q && !err_clr);
      parity_q  <= perr_ev || (parity_q && !err_clr);
      err_q     <= ovr_ev || ferr_ev || perr_ev || (err_q && !err_clr);
    end
  end

  logic [2:0] irq_st;
  assign irq_st = {err_q, rx_wm, tx_wm};
  assign irq    = |(irq_st & irq_en_q);

  always_comb begin
    case (paddr)
      A_DATA:   prdata = {rx_empty, 23'b0, rx_rdata};
      A_STATUS: prdata = {11'b0, 5'(rx_level), 3'b0, 5'(tx_level), parity_q, frame_q, overrun_q,
                          rx_full, rx_empty, !tx_busy && tx_empty, tx_empty, tx_full};
      A_CTRL:   prdata = {27'b0, ctrl_q};
      A_BAUD:   prdata = {16'b0, baud_q};
      A_IRQ_EN: prdata = {29'b0, irq_en_q};
      A_IRQ_ST: prdata = {29'b0, irq_st};
      A_WM:     prdata = {11'b0, wm_rx_q, 11'b0, wm_tx_q};
      default:  prdata = 32'b0;
    endcase
  end

endmodule
