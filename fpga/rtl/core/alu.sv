// ============================================================================
// alu.sv - RV32I integer ALU (purely combinational).
//
// Ports:
//   op     : ALU_* encoding (rv_pkg)
//   a, b   : operands
//   result : a <op> b
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module alu
(
  input  logic [3:0]  op,
  input  logic [31:0] a,
  input  logic [31:0] b,
  output logic [31:0] result
);

  logic [32:0] diff;  // a - b with borrow, shared by SUB/SLT/SLTU
  logic        lt_s;
  logic        lt_u;

  assign diff = {1'b0, a} - {1'b0, b};
`ifdef COSIM_MUTANT
  // Deliberate bug, only for the co-simulation demonstration (scripts/run_cosim.py):
  // SLTU takes bit 31 of the difference instead of the borrow.
  assign lt_u = diff[31];
`else
  assign lt_u = diff[32];
`endif
  assign lt_s = (a[31] != b[31]) ? a[31] : diff[31];

  always_comb begin
    case (op)
      ALU_ADD:  result = a + b;
      ALU_SUB:  result = diff[31:0];
      ALU_SLL:  result = a << b[4:0];
      ALU_SLT:  result = {31'b0, lt_s};
      ALU_SLTU: result = {31'b0, lt_u};
      ALU_XOR:  result = a ^ b;
      ALU_SRL:  result = a >> b[4:0];
      ALU_SRA:  result = $signed(a) >>> b[4:0];
      ALU_OR:   result = a | b;
      ALU_AND:  result = a & b;
      default:  result = a + b;
    endcase
  end

endmodule
