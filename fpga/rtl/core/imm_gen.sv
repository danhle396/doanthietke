// ============================================================================
// imm_gen.sv - Immediate generator for 32-bit RISC-V encodings.
//
// Ports:
//   insn     : 32-bit instruction
//   imm_type : IMM_I/S/B/U/J/Z (rv_pkg)
//   imm      : sign-extended immediate (IMM_Z: zero-extended CSR address)
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module imm_gen
(
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [31:0] insn,  // opcode bits [6:0] carry no immediate
  /* verilator lint_on UNUSEDSIGNAL */
  input  logic [2:0]  imm_type,
  output logic [31:0] imm
);

  always_comb begin
    case (imm_type)
      IMM_S:   imm = {{21{insn[31]}}, insn[30:25], insn[11:7]};
      IMM_B:   imm = {{20{insn[31]}}, insn[7], insn[30:25], insn[11:8], 1'b0};
      IMM_U:   imm = {insn[31:12], 12'b0};
      IMM_J:   imm = {{12{insn[31]}}, insn[19:12], insn[20], insn[30:21], 1'b0};
      IMM_Z:   imm = {20'b0, insn[31:20]};
      default: imm = {{21{insn[31]}}, insn[30:20]};  // IMM_I
    endcase
  end

endmodule
