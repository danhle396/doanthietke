// ============================================================================
// ram_dp.sv - Unified dual-port RAM (instructions + data).
//   Combinational read on both ports, synchronous byte-enable write on the
//   D-port. The I-port returns 32 bits starting at any halfword address:
//     addr[1] = 0 -> word[i]
//     addr[1] = 1 -> {word[i+1][15:0], word[i][31:16]} (0 beyond the end)
//   so a 32-bit instruction straddling a word boundary is fetched in one
//   cycle. Simulation: preloaded with $readmemh from +hex=<file>.
//   Synthesis: treated as a black box (maps to LUTRAM on FPGA).
//
// Ports:
//   i_addr, i_rdata, i_err : instruction port (err = outside RAM)
//   d_req, d_we, d_be, d_addr, d_wdata, d_rdata, d_ready : data port
// Parameters:
//   BASE  : byte address of word 0
//   DEPTH : number of 32-bit words (32768 = 128 KB)
// ============================================================================
module ram_dp #(
  parameter logic [31:0] BASE  = 32'h8000_0000,
  parameter int          DEPTH = 32768
) (
  input  logic        clk,
  // instruction port
  input  logic [31:0] i_addr,
  output logic [31:0] i_rdata,
  output logic        i_err,
  // data port
  input  logic        d_req,
  input  logic        d_we,
  input  logic [3:0]  d_be,
  input  logic [31:0] d_addr,
  input  logic [31:0] d_wdata,
  output logic [31:0] d_rdata,
  output logic        d_ready
);

  localparam int AW = $clog2(DEPTH);
  localparam logic [31:0] SIZE = DEPTH * 4;

  logic [31:0] mem [DEPTH];

  // ---------------- I-port ----------------
  logic [31:0] i_off;
  logic [AW-1:0] i_idx, i_idx_next;
  logic        i_last;
  logic [31:0] w0;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] w1;  // only the low halfword of the next word is needed
  /* verilator lint_on UNUSEDSIGNAL */

  assign i_off      = i_addr - BASE;
  assign i_err      = (i_addr < BASE) || (i_off >= SIZE);
  assign i_idx      = i_off[AW+1:2];
  assign i_idx_next = i_idx + 1'b1;
  assign i_last     = (i_idx == AW'(DEPTH - 1));
  assign w0         = mem[i_idx];
  assign w1         = i_last ? 32'b0 : mem[i_idx_next];
  assign i_rdata    = i_addr[1] ? {w1[15:0], w0[31:16]} : w0;

  // ---------------- D-port ----------------
  logic [31:0]   d_off;
  logic [AW-1:0] d_idx;

  assign d_off   = d_addr - BASE;
  assign d_idx   = d_off[AW+1:2];
  assign d_rdata = mem[d_idx];
  assign d_ready = d_req;

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

  /* verilator lint_off UNUSEDSIGNAL */
  // Upper offset bits only matter for the range check.
  logic unused;
  assign unused = ^{i_off[31:AW+2], i_off[0], d_off[31:AW+2], d_off[1:0]};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
