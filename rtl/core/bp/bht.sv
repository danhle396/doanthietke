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

  // packed array: plain registers for synthesis (no memory inference)
  logic [ENTRIES-1:0][1:0] cnt_q;
  logic [IW-1:0] rd_idx, upd_idx;

  assign rd_idx   = rd_pc[IW:1];
  assign upd_idx  = upd_pc[IW:1];
  assign rd_taken = cnt_q[rd_idx][1];

  // one register per entry (explicit decode: synthesizes to plain flip-flops)
  for (genvar i = 0; i < ENTRIES; i++) begin : g_e
    logic [1:0] c_q;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) c_q <= 2'b01;
      else if (upd_en && upd_idx == IW'(i)) begin
        if (upd_taken && c_q != 2'b11)       c_q <= c_q + 2'b01;
        else if (!upd_taken && c_q != 2'b00) c_q <= c_q - 2'b01;
      end
    end
    assign cnt_q[i] = c_q;
  end

endmodule
