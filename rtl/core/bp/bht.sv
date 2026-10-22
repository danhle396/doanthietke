// ============================================================================
// bht.sv - Branch History Table: 2-bit saturating counters.
//   Reset value 2'b01 (weakly not-taken). Index = pc[log2(ENTRIES):1].
//
// Ports:
//   rd_pc    : lookup PC (combinational read)
//   rd_taken : prediction (counter[1])
//   upd_en   : update counter of upd_pc with outcome upd_taken
// Parameters:
//   ENTRIES  : power of two, >= 16
// ============================================================================
module bht #(
  parameter int ENTRIES = 256
) (
  input  logic        clk,
  input  logic        rst_n,
  /* verilator lint_off UNUSEDSIGNAL */
  // Only the index bits of the PCs are used.
  input  logic [31:0] rd_pc,
  output logic        rd_taken,
  input  logic        upd_en,
  input  logic [31:0] upd_pc,
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic        upd_taken
);

  localparam int IW = $clog2(ENTRIES);

  logic [1:0]    cnt_q [ENTRIES];
  logic [IW-1:0] rd_idx, upd_idx;
  logic [1:0]    cur;

  assign rd_idx   = rd_pc[IW:1];
  assign upd_idx  = upd_pc[IW:1];
  assign rd_taken = cnt_q[rd_idx][1];
  assign cur      = cnt_q[upd_idx];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < ENTRIES; i++) cnt_q[i] <= 2'b01;
    end else if (upd_en) begin
      if (upd_taken && cur != 2'b11)      cnt_q[upd_idx] <= cur + 2'b01;
      else if (!upd_taken && cur != 2'b00) cnt_q[upd_idx] <= cur - 2'b01;
    end
  end

endmodule
