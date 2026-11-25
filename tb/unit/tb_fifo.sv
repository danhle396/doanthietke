`timescale 1ns/1ps
`include "tb_common.svh"

module tb_fifo;
  `TB_DECLS

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic       push, pop, full, empty, full16, empty16;
  logic [7:0] wdata, rdata, rdata16;
  logic [2:0] level;
  logic [4:0] level16;

  sync_fifo #(.WIDTH(8), .DEPTH(4))  d4  (.clk, .rst_n, .push, .wdata, .pop, .rdata, .full,
                                          .empty, .level);
  sync_fifo #(.WIDTH(8), .DEPTH(16)) d16 (.clk, .rst_n, .push, .wdata, .pop, .rdata(rdata16),
                                          .full(full16), .empty(empty16), .level(level16));

  byte q4[$], q16[$];

  task automatic step(input logic ps, input logic pp, input logic [7:0] d);
    @(negedge clk);
    push = ps; pop = pp; wdata = d;
    #1;
    // combinational checks before the edge
    `CHECK(empty == (q4.size() == 0) && full == (q4.size() == 4) && level == 3'(q4.size()),
           $sformatf("d4 flags: empty=%0d full=%0d level=%0d model=%0d", empty, full, level, q4.size()))
    `CHECK(empty16 == (q16.size() == 0) && full16 == (q16.size() == 16) && level16 == 5'(q16.size()),
           $sformatf("d16 flags: level=%0d model=%0d", level16, q16.size()))
    if (q4.size() != 0)  `CHECK(rdata == q4[0], $sformatf("d4 FWFT data %02x exp %02x", rdata, q4[0]))
    if (q16.size() != 0) `CHECK(rdata16 == q16[0], "d16 FWFT data")
    // model update (same rules as the RTL)
    begin
      bit p4, p16;
      p4 = pp && q4.size() != 0;
      p16 = pp && q16.size() != 0;
      if (p4) void'(q4.pop_front());
      if (p16) void'(q16.pop_front());
      if (ps && (q4.size() < 4)) q4.push_back(d);
      if (ps && (q16.size() < 16)) q16.push_back(d);
    end
  endtask

  `TB_TIMEOUT(10ms)

  initial begin
    `TB_INIT
    push = 0; pop = 0; wdata = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    step(0, 1, 0);                                      // pop when empty: ignored
    step(1, 1, 8'h11);                                  // push+pop when empty: push only
    for (int i = 0; i < 20; i++) step(1, 0, 8'(i));     // fill beyond full
    step(1, 1, 8'hAA);                                  // push+pop when full (d4): both
    step(1, 0, 8'hBB);                                  // push when full: ignored
    for (int i = 0; i < 20; i++) step(0, 1, 0);         // drain beyond empty
    for (int n = 0; n < 20000; n++)
      step(1'($urandom_range(0, 1)), 1'($urandom_range(0, 1)), 8'($urandom));
    `TB_FINISH
  end
endmodule
