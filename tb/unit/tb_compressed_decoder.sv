`timescale 1ns/1ps
`include "tb_common.svh"

module tb_compressed_decoder;
  `TB_DECLS
`include "rvc_vectors.svh"

  logic [15:0] cinsn;
  logic [31:0] insn;
  logic        illegal;
  logic [47:0] vec [N_VEC];
  logic [15:0] ill [N_ILL];
  int          order [N_VEC];

  compressed_decoder dut (.cinsn, .insn, .illegal);

  initial begin
    `TB_INIT
    $readmemh("gen/rvc_vectors.hex", vec);
    $readmemh("gen/rvc_illegal.hex", ill);
    foreach (order[i]) order[i] = i;
    order.shuffle();
    foreach (order[k]) begin
      int i = order[k];
      cinsn = vec[i][47:32];
      #1;
      `CHECK(!illegal && insn === vec[i][31:0],
             $sformatf("c=%04x got %08x ill=%0d exp %08x", cinsn, insn, illegal, vec[i][31:0]))
    end
    foreach (ill[i]) begin
      cinsn = ill[i];
      #1;
      `CHECK(illegal === 1'b1, $sformatf("c=%04x should be illegal (got insn %08x)", cinsn, insn))
    end
    // 32-bit encodings never reach this unit as legal 16-bit instructions
    for (int n = 0; n < 1000; n++) begin
      cinsn = 16'($urandom) | 16'h0003;
      #1;
      `CHECK(illegal === 1'b1, $sformatf("c=%04x (bits[1:0]=11) not flagged", cinsn))
    end
    $display("[tb_compressed_decoder] %0d vectors, %0d illegal encodings", N_VEC, N_ILL);
    `TB_FINISH
  end
endmodule
