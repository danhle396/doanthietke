/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module branch_unit
(
  input  logic [31:0] pc,
  input  logic [31:0] imm,
  input  logic [31:0] rs1,
  input  logic [31:0] rs2,
  input  logic        is_branch,
  input  logic        is_jal,
  input  logic        is_jalr,
  input  logic [2:0]  funct3,
  input  logic        is_c,
  output logic        taken,
  output logic [31:0] target,
  output logic [31:0] link,
  output logic [31:0] actual_npc
);

  logic        cond;
  logic        eq;
  logic        lt_s;
  logic        lt_u;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] jalr_sum;  // bit 0 cleared by JALR semantics
  /* verilator lint_on UNUSEDSIGNAL */

  assign eq   = (rs1 == rs2);
  assign lt_s = ($signed(rs1) < $signed(rs2));
  assign lt_u = (rs1 < rs2);

  always_comb begin
    case (funct3)
      F3_BEQ:  cond = eq;
      F3_BNE:  cond = !eq;
      F3_BLT:  cond = lt_s;
      F3_BGE:  cond = !lt_s;
      F3_BLTU: cond = lt_u;
      F3_BGEU: cond = !lt_u;
      default: cond = 1'b0;
    endcase
  end

  assign jalr_sum   = rs1 + imm;
  assign taken      = is_jal || is_jalr || (is_branch && cond);
  assign target     = is_jalr ? {jalr_sum[31:1], 1'b0} : (pc + imm);
  assign link       = pc + (is_c ? 32'd2 : 32'd4);
  assign actual_npc = taken ? target : link;

endmodule
