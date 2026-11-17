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

  // packed arrays: plain registers for synthesis (no memory inference)
  logic [ENTRIES-1:0]         valid_q;
  logic [ENTRIES-1:0][TW-1:0] tag_q;
  logic [ENTRIES-1:0][30:0]   target_q;
  logic [ENTRIES-1:0][1:0]    type_q;

  logic [IW-1:0] rd_idx, wr_idx, inv_idx;

  assign rd_idx    = rd_pc[IW:1];
  assign wr_idx    = wr_pc[IW:1];
  assign inv_idx   = inv_pc[IW:1];
  assign rd_hit    = valid_q[rd_idx] && (tag_q[rd_idx] == rd_pc[31:IW+1]);
  assign rd_target = {target_q[rd_idx], 1'b0};
  assign rd_type   = type_q[rd_idx];

  // one register set per entry (explicit decode: plain flip-flops)
  genvar i;
  generate
  for (i = 0; i < ENTRIES; i = i + 1) begin : g_e
    logic          v_q;
    logic [TW-1:0] tag_e;
    logic [30:0]   tgt_e;
    logic [1:0]    ty_e;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        v_q   <= 1'b0;
        tag_e <= '0;
        tgt_e <= '0;
        ty_e  <= 2'b00;
      end else if (wr_en && wr_idx == IW'(i)) begin
        v_q   <= 1'b1;
        tag_e <= wr_pc[31:IW+1];
        tgt_e <= wr_target[31:1];
        ty_e  <= wr_type;
      end else if (!wr_en && inv_en && inv_idx == IW'(i)) begin
        v_q   <= 1'b0;
      end
    end
    assign valid_q[i]  = v_q;
    assign tag_q[i]    = tag_e;
    assign target_q[i] = tgt_e;
    assign type_q[i]   = ty_e;
  end
  endgenerate

endmodule
