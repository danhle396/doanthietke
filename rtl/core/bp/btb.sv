// ============================================================================
// btb.sv - Direct-mapped Branch Target Buffer.
//   Entry = {valid, tag, target[31:1], type}; index = pc[log2(ENTRIES):1],
//   tag = remaining bits of pc[31:1].
//
// Ports:
//   rd_pc, rd_hit, rd_target, rd_type : combinational lookup
//   wr_en, wr_pc, wr_target, wr_type  : allocate/update an entry
//   inv_en, inv_pc                    : invalidate entry of inv_pc (alias)
// Parameters:
//   ENTRIES : power of two, >= 4
// ============================================================================
module btb #(
  parameter int ENTRIES = 32
) (
  input  logic        clk,
  input  logic        rst_n,
  /* verilator lint_off UNUSEDSIGNAL */
  // PC bit 0 is always 0; inv_pc only needs the index bits.
  input  logic [31:0] rd_pc,
  output logic        rd_hit,
  output logic [31:0] rd_target,
  output logic [1:0]  rd_type,
  input  logic        wr_en,
  input  logic [31:0] wr_pc,
  input  logic [31:0] wr_target,
  input  logic [1:0]  wr_type,
  input  logic        inv_en,
  input  logic [31:0] inv_pc
  /* verilator lint_on UNUSEDSIGNAL */
);

  localparam int IW = $clog2(ENTRIES);
  localparam int TW = 31 - IW;  // tag width: pc[31:IW+1]

  logic          valid_q  [ENTRIES];
  logic [TW-1:0] tag_q    [ENTRIES];
  logic [30:0]   target_q [ENTRIES];
  logic [1:0]    type_q   [ENTRIES];

  logic [IW-1:0] rd_idx, wr_idx, inv_idx;

  assign rd_idx    = rd_pc[IW:1];
  assign wr_idx    = wr_pc[IW:1];
  assign inv_idx   = inv_pc[IW:1];
  assign rd_hit    = valid_q[rd_idx] && (tag_q[rd_idx] == rd_pc[31:IW+1]);
  assign rd_target = {target_q[rd_idx], 1'b0};
  assign rd_type   = type_q[rd_idx];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < ENTRIES; i++) begin
        valid_q[i]  <= 1'b0;
        tag_q[i]    <= '0;
        target_q[i] <= '0;
        type_q[i]   <= 2'b00;
      end
    end else if (wr_en) begin
      valid_q[wr_idx]  <= 1'b1;
      tag_q[wr_idx]    <= wr_pc[31:IW+1];
      target_q[wr_idx] <= wr_target[31:1];
      type_q[wr_idx]   <= wr_type;
    end else if (inv_en) begin
      valid_q[inv_idx] <= 1'b0;
    end
  end

endmodule
