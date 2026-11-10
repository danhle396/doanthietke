// ============================================================================
// timer64_apb.sv - 64-bit machine timer (APB slave, 0x1000_2000).
//   0x00 MTIME_LO, 0x04 MTIME_HI (RW)
//   0x08 MTIMECMP_LO, 0x0C MTIMECMP_HI (RW, reset 0xFFFF_FFFF)
//   0x10 CTRL: [0] EN (reset 1), [15:8] PRESCALE (reset 0) - mtime += 1
//        every PRESCALE + 1 clocks
//   0x14 MSIP: [0] -> msip
//   mtip = (mtime >= mtimecmp) (level). A register write takes precedence
//   over the increment in the same cycle.
//
// Ports: APB4 slave (paddr[11:0]), mtime[63:0], mtip, msip.
// ============================================================================
module timer64_apb (
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
  output logic [63:0] mtime,
  output logic        mtip,
  output logic        msip
);

  localparam logic [11:0] A_MTIME_LO = 12'h00, A_MTIME_HI = 12'h04, A_CMP_LO = 12'h08,
                          A_CMP_HI = 12'h0C, A_CTRL = 12'h10, A_MSIP = 12'h14;

  logic valid_off, wr;
  assign valid_off = (paddr == A_MTIME_LO) || (paddr == A_MTIME_HI) || (paddr == A_CMP_LO) ||
                     (paddr == A_CMP_HI) || (paddr == A_CTRL) || (paddr == A_MSIP);
  assign wr      = psel && penable && pwrite && valid_off;
  assign pready  = 1'b1;
  assign pslverr = psel && penable && !valid_off;

  function automatic logic [31:0] merge(input logic [31:0] old, input logic [31:0] nw,
                                        input logic [3:0] strb);
    merge = old;
    for (int b = 0; b < 4; b++) if (strb[b]) merge[b*8 +: 8] = nw[b*8 +: 8];
  endfunction

  logic [31:0] bmask;   // PSTRB expanded to bits
  assign bmask = {{8{pstrb[3]}}, {8{pstrb[2]}}, {8{pstrb[1]}}, {8{pstrb[0]}}};

  logic [63:0] mtime_q, cmp_q;
  logic        en_q, msip_q;
  logic [7:0]  prescale_q, pre_cnt_q;
  logic        tick;

  /* verilator lint_off UNUSEDSIGNAL */
  // Full-width merged write values; only the implemented bits are stored.
  logic [31:0] ctrl_w, msip_w;
  /* verilator lint_on UNUSEDSIGNAL */
  assign ctrl_w = merge({16'b0, prescale_q, 7'b0, en_q}, pwdata, pstrb);
  assign msip_w = merge({31'b0, msip_q}, pwdata, pstrb);
  assign tick   = en_q && (pre_cnt_q == prescale_q);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mtime_q    <= 64'b0;
      cmp_q      <= 64'hFFFF_FFFF_FFFF_FFFF;
      en_q       <= 1'b1;
      prescale_q <= 8'd0;
      pre_cnt_q  <= 8'd0;
      msip_q     <= 1'b0;
    end else begin
      if (en_q) pre_cnt_q <= tick ? 8'd0 : pre_cnt_q + 8'd1;

      if (wr && paddr == A_MTIME_LO)
        mtime_q <= {mtime_q[63:32], (mtime_q[31:0] & ~bmask) | (pwdata & bmask)};
      else if (wr && paddr == A_MTIME_HI)
        mtime_q <= {(mtime_q[63:32] & ~bmask) | (pwdata & bmask), mtime_q[31:0]};
      else if (tick)
        mtime_q <= mtime_q + 64'd1;

      if (wr && paddr == A_CMP_LO) cmp_q[31:0]  <= (cmp_q[31:0] & ~bmask) | (pwdata & bmask);
      if (wr && paddr == A_CMP_HI) cmp_q[63:32] <= (cmp_q[63:32] & ~bmask) | (pwdata & bmask);
      if (wr && paddr == A_CTRL) begin
        en_q       <= ctrl_w[0];
        prescale_q <= ctrl_w[15:8];
        pre_cnt_q  <= 8'd0;
      end
      if (wr && paddr == A_MSIP) msip_q <= msip_w[0];
    end
  end

  assign mtime = mtime_q;
  assign mtip  = (mtime_q >= cmp_q);
  assign msip  = msip_q;

  always_comb begin
    case (paddr)
      A_MTIME_LO: prdata = mtime_q[31:0];
      A_MTIME_HI: prdata = mtime_q[63:32];
      A_CMP_LO:   prdata = cmp_q[31:0];
      A_CMP_HI:   prdata = cmp_q[63:32];
      A_CTRL:     prdata = {16'b0, prescale_q, 7'b0, en_q};
      A_MSIP:     prdata = {31'b0, msip_q};
      default:    prdata = 32'b0;
    endcase
  end

endmodule
