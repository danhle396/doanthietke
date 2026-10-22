// tb_alu.sv - ALU vs. reference model: boundary values x all ops, then
// >= 10,000 random vectors (seed from +seed=).
`timescale 1ns/1ps
`include "tb_common.svh"

module tb_alu;
  import rv_pkg::*;
  `TB_DECLS

  logic [3:0]  op;
  logic [31:0] a, b, result;

  alu dut (.op, .a, .b, .result);

  function automatic logic [31:0] model(input logic [3:0] o, input logic [31:0] x,
                                        input logic [31:0] y);
    case (o)
      ALU_ADD:  return x + y;
      ALU_SUB:  return x - y;
      ALU_SLL:  return x << y[4:0];
      ALU_SLT:  return ($signed(x) < $signed(y)) ? 32'd1 : 32'd0;
      ALU_SLTU: return (x < y) ? 32'd1 : 32'd0;
      ALU_XOR:  return x ^ y;
      ALU_SRL:  return x >> y[4:0];
      ALU_SRA:  return 32'($signed(x) >>> y[4:0]);
      ALU_OR:   return x | y;
      ALU_AND:  return x & y;
      default:  return x + y;
    endcase
  endfunction

  task automatic check(input logic [3:0] o, input logic [31:0] x, input logic [31:0] y);
    logic [31:0] exp;
    op = o; a = x; b = y;
    #1;
    exp = model(o, x, y);
    `CHECK(result === exp, $sformatf("op=%0d a=%08x b=%08x got %08x exp %08x", o, x, y, result, exp))
  endtask

  logic [31:0] edges [12] = '{32'h0, 32'h1, 32'h2, 32'h1F, 32'h20, 32'h7FFF_FFFF,
                              32'h8000_0000, 32'h8000_0001, 32'hFFFF_FFFF, 32'hFFFF_FFFE,
                              32'h5555_5555, 32'hAAAA_AAAA};

  initial begin
    `TB_INIT
    // boundary values: every op x every pair
    for (int o = 0; o <= 9; o++)
      foreach (edges[i])
        foreach (edges[j])
          check(4'(o), edges[i], edges[j]);
    // random vectors
    for (int n = 0; n < 12000; n++)
      check(4'($urandom_range(0, 9)), $urandom, $urandom);
    // random with small shift amounts / near-equal operands
    for (int n = 0; n < 2000; n++) begin
      logic [31:0] x;
      x = $urandom;
      check(4'($urandom_range(0, 9)), x, x + 32'($urandom_range(0, 2)) - 32'd1);
    end
    `TB_FINISH
  end
endmodule
