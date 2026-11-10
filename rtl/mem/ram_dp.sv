// ============================================================================
// ram_dp.sv - Unified dual-port RAM (instructions + data).
//   The I-port returns 32 bits starting at any halfword address:
//     addr[1] = 0 -> word[i]
//     addr[1] = 1 -> {word[i+1][15:0], word[i][31:16]} (0 beyond the end)
//   so a 32-bit instruction straddling a word boundary is fetched in one
//   cycle. Two implementations with identical cycle behaviour:
//   SYNC = 0 : combinational read on both ports, byte-enable write at the
//              rising edge (LUTRAM; default for simulation and the reports).
//   SYNC = 1 : two 16-bit banks (ram_bank16) clocked on the falling edge,
//              for FPGAs whose block RAM only reads synchronously (M4K on
//              Cyclone II). Bank 0 holds the even halfwords, bank 1 the odd
//              ones, so the two halfwords of any fetch come from different
//              banks. Addresses come from registers (pc_q, ex_mem), so they
//              are stable by the falling edge; read data is ready before the
//              next rising edge. A store is written at the falling edge of
//              its own cycle; reads in that cycle return the old data, as in
//              the combinational model.
//   Simulation: preloaded with $readmemh from +hex=<file>.
//   Synthesis (Yosys reports): treated as a black box.
//
// Ports (Wishbone B4 classic slaves, zero wait states: ACK in the cycle of
// the request):
//   wbi_* : instruction port, read only; ADR may be halfword aligned (see
//           above); ERR instead of ACK outside the RAM (fetch access fault)
//   wbd_* : data port, SEL = byte enables (the interconnect only selects it
//           for addresses inside the RAM)
// Parameters:
//   BASE  : byte address of word 0
//   DEPTH : number of 32-bit words (32768 = 128 KB)
//   SYNC  : 0 = combinational read, 1 = falling-edge banked RAM
// ============================================================================
module ram_dp #(
  parameter logic [31:0] BASE  = 32'h8000_0000,
  parameter int          DEPTH = 32768,
  parameter bit          SYNC  = 1'b0
) (
  input  logic        clk,
  // instruction port (Wishbone slave, read only)
  input  logic        wbi_cyc_i,
  input  logic        wbi_stb_i,
  input  logic [31:0] wbi_adr_i,
  output logic [31:0] wbi_dat_o,
  output logic        wbi_ack_o,
  output logic        wbi_err_o,
  // data port (Wishbone slave)
  input  logic        wbd_cyc_i,
  input  logic        wbd_stb_i,
  input  logic        wbd_we_i,
  input  logic [3:0]  wbd_sel_i,
  input  logic [31:0] wbd_adr_i,
  input  logic [31:0] wbd_dat_i,
  output logic [31:0] wbd_dat_o,
  output logic        wbd_ack_o
);

  localparam int AW = $clog2(DEPTH);
  localparam logic [31:0] SIZE = DEPTH * 4;

  // ---------------- Wishbone ports -> internal request view ----------------
  logic [31:0] i_addr, i_rdata, d_addr, d_wdata, d_rdata;
  logic        i_req, i_err, d_req, d_we;
  logic [3:0]  d_be;

  assign i_req     = wbi_cyc_i && wbi_stb_i;
  assign i_addr    = wbi_adr_i;
  assign wbi_dat_o = i_rdata;
  assign wbi_ack_o = i_req && !i_err;
  assign wbi_err_o = i_req && i_err;

  assign d_req     = wbd_cyc_i && wbd_stb_i;
  assign d_we      = wbd_we_i;
  assign d_be      = wbd_sel_i;
  assign d_addr    = wbd_adr_i;
  assign d_wdata   = wbd_dat_i;
  assign wbd_dat_o = d_rdata;
  assign wbd_ack_o = d_req;

  // ---------------- address decode (both implementations) ----------------
  logic [31:0]   i_off, d_off;
  logic [AW-1:0] i_idx, d_idx;
  logic          i_last;

  assign i_off   = i_addr - BASE;
  assign i_err   = (i_addr < BASE) || (i_off >= SIZE);
  assign i_idx   = i_off[AW+1:2];
  assign i_last  = (i_idx == AW'(DEPTH - 1));
  assign d_off   = d_addr - BASE;
  assign d_idx   = d_off[AW+1:2];

  if (!SYNC) begin : g_comb
    logic [31:0]   mem [DEPTH];
    logic [AW-1:0] i_idx_next;
    logic [31:0]   w0;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0]   w1;  // only the low halfword of the next word is needed
    /* verilator lint_on UNUSEDSIGNAL */

    assign i_idx_next = i_idx + 1'b1;
    assign w0         = mem[i_idx];
    assign w1         = i_last ? 32'b0 : mem[i_idx_next];
    assign i_rdata    = i_addr[1] ? {w1[15:0], w0[31:16]} : w0;
    assign d_rdata    = mem[d_idx];

    always_ff @(posedge clk) begin
      if (d_req && d_we) begin
        for (int b = 0; b < 4; b++)
          if (d_be[b]) mem[d_idx][b*8 +: 8] <= d_wdata[b*8 +: 8];
      end
    end

`ifndef SYNTHESIS
    string hex_file;
    initial begin
      for (int i = 0; i < DEPTH; i++) mem[i] = 32'b0;
      if ($value$plusargs("hex=%s", hex_file)) $readmemh(hex_file, mem);
    end
`endif
  end else begin : g_sync
    // fetch at halfword h: even h -> {b1[h/2], b0[h/2]},
    //                      odd h  -> {b0[h/2 + 1], b1[h/2]}
    logic [AW-1:0] b0_iaddr;
    logic [15:0]   b0_iq, b1_iq, b0_dq, b1_dq;
    logic          d_we_q;

    assign b0_iaddr = i_idx + AW'(i_addr[1]);
    assign d_we_q   = d_req && d_we;

    ram_bank16 #(.DEPTH(DEPTH), .HALF(0)) u_bank0 (
      .clk,
      .a_addr(d_idx), .a_we(d_we_q), .a_be(d_be[1:0]), .a_wdata(d_wdata[15:0]), .a_rdata(b0_dq),
      .b_addr(b0_iaddr), .b_rdata(b0_iq)
    );
    ram_bank16 #(.DEPTH(DEPTH), .HALF(1)) u_bank1 (
      .clk,
      .a_addr(d_idx), .a_we(d_we_q), .a_be(d_be[3:2]), .a_wdata(d_wdata[31:16]), .a_rdata(b1_dq),
      .b_addr(i_idx), .b_rdata(b1_iq)
    );

    assign i_rdata = i_addr[1] ? {(i_last ? 16'b0 : b0_iq), b1_iq} : {b1_iq, b0_iq};
    assign d_rdata = {b1_dq, b0_dq};
  end

  /* verilator lint_off UNUSEDSIGNAL */
  // Upper offset bits only matter for the range check.
  logic unused;
  assign unused = ^{i_off[31:AW+2], i_off[0], d_off[31:AW+2], d_off[1:0]};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
