`timescale 1ns/1ps
`include "tb_common.svh"

module tb_regfile;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        we;
  logic [4:0]  waddr, raddr1, raddr2;
  logic [31:0] wdata, rdata1, rdata2;
  logic [31:0] model [32];

  always #5 clk = ~clk;

  regfile #(.WRITE_THROUGH(1'b1)) dut (.*);

  task automatic step(input logic w, input logic [4:0] wa, input logic [31:0] wd,
                      input logic [4:0] r1, input logic [4:0] r2);
    logic [31:0] e1, e2;
    @(negedge clk);
    we = w; waddr = wa; wdata = wd; raddr1 = r1; raddr2 = r2;
    #1;
    // expected (write-through)
    e1 = (r1 == 0) ? 0 : ((w && wa == r1) ? wd : model[r1]);
    e2 = (r2 == 0) ? 0 : ((w && wa == r2) ? wd : model[r2]);
    `CHECK(rdata1 === e1, $sformatf("r1 x%0d got %08x exp %08x", r1, rdata1, e1))
    `CHECK(rdata2 === e2, $sformatf("r2 x%0d got %08x exp %08x", r2, rdata2, e2))
    @(posedge clk);
    if (w && wa != 0) model[wa] = wd;
  endtask

  `TB_TIMEOUT(10ms)

  initial begin
    `TB_INIT
    foreach (model[i]) model[i] = 0;
    we = 0; waddr = 0; wdata = 0; raddr1 = 0; raddr2 = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    // after reset all registers read 0
    for (int r = 0; r < 32; r++) step(0, 0, 0, 5'(r), 5'(31 - r));
    // x0: writes are ignored, even with write-through
    step(1, 0, 32'hDEAD_BEEF, 0, 0);
    step(0, 0, 0, 0, 0);
    // write-through on both ports
    step(1, 5, 32'h1234_5678, 5, 5);
    step(1, 6, 32'hCAFE_F00D, 5, 6);
    // fill all registers then read back
    for (int r = 1; r < 32; r++) step(1, 5'(r), 32'(r * 32'h0101_0101), 5'(r), 5'(r - 1));
    // random
    for (int n = 0; n < 20000; n++)
      step(1'($urandom_range(0, 1)), 5'($urandom), $urandom, 5'($urandom), 5'($urandom));
    `TB_FINISH
  end
endmodule
