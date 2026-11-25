`timescale 1ns/1ps
`include "tb_common.svh"

module tb_muldiv;
  import rv_pkg::*;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        valid, kill, advance, ready, busy;
  logic [2:0]  op;
  logic [31:0] a, b, result;

  always #5 clk = ~clk;

  muldiv dut (.clk, .rst_n, .valid, .op, .a, .b, .kill, .advance, .ready, .result, .busy);

  function automatic logic [31:0] model(input logic [2:0] o, input logic [31:0] x,
                                        input logic [31:0] y);
    longint sx, sy, ux, uy;
    longint p;
    sx = longint'($signed(x)); sy = longint'($signed(y));
    ux = longint'({32'b0, x}); uy = longint'({32'b0, y});
    case (o)
      MD_MUL:    begin p = sx * sy; return p[31:0]; end
      MD_MULH:   begin p = sx * sy; return p[63:32]; end
      MD_MULHSU: begin p = sx * uy; return p[63:32]; end
      MD_MULHU:  begin
        logic [63:0] up;
        up = {32'b0, x} * {32'b0, y};
        return up[63:32];
      end
      MD_DIV:  return (y == 0) ? 32'hFFFF_FFFF :
                      (x == 32'h8000_0000 && y == 32'hFFFF_FFFF) ? 32'h8000_0000 :
                      32'($signed(x) / $signed(y));
      MD_DIVU: return (y == 0) ? 32'hFFFF_FFFF : x / y;
      MD_REM:  return (y == 0) ? x :
                      (x == 32'h8000_0000 && y == 32'hFFFF_FFFF) ? 32'h0 :
                      32'($signed(x) % $signed(y));
      default: return (y == 0) ? x : x % y;  // REMU
    endcase
  endfunction

  int max_lat = 0;

  // Issue one operation; hold_cycles = extra cycles with ready but no advance.
  task automatic do_op(input logic [2:0] o, input logic [31:0] x, input logic [31:0] y,
                       input int hold_cycles = 0);
    int lat;
    logic [31:0] exp;
    exp = model(o, x, y);
    @(negedge clk);
    valid = 1; op = o; a = x; b = y; advance = 0; kill = 0;
    lat = 0;
    #1;
    while (!ready) begin
      @(negedge clk); #1;
      lat++;
      if (lat > 40) begin
        `CHECK(0, $sformatf("op=%0d no ready after 40 cycles", o))
        break;
      end
    end
    // operands may change while the divider runs (latched at start)
    for (int h = 0; h < hold_cycles; h++) begin
      `CHECK(ready && result === exp, $sformatf("hold op=%0d result lost", o))
      @(negedge clk); #1;
    end
    `CHECK(result === exp, $sformatf("op=%0d a=%08x b=%08x got %08x exp %08x lat=%0d",
                                     o, x, y, result, exp, lat))
    if (lat > max_lat) max_lat = lat;
    advance = 1;
    @(negedge clk);
    valid = 0; advance = 0;
  endtask

  // Start a division, kill it after `k` cycles, check the unit is idle again.
  task automatic abort_div(input int k);
    @(negedge clk);
    valid = 1; op = MD_DIVU; a = $urandom | 32'h1; b = ($urandom >> 4) | 32'h1;
    advance = 0; kill = 0;
    repeat (k) @(negedge clk);
    kill = 1;
    a = 32'hDEAD_BEEF;  // operands change as the instruction is flushed
    @(negedge clk);
    kill = 0; valid = 0;
    #1;
    `CHECK(!busy, "divider still busy after kill")
  endtask

  logic [31:0] edges [8] = '{32'h0, 32'h1, 32'hFFFF_FFFF, 32'h8000_0000, 32'h7FFF_FFFF,
                             32'h2, 32'hFFFF_FFFE, 32'h0001_0000};

  `TB_TIMEOUT(50ms)

  initial begin
    `TB_INIT
    valid = 0; kill = 0; advance = 0; op = 0; a = 0; b = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    // boundary values: 8 ops x 8 x 8
    for (int o = 0; o < 8; o++)
      foreach (edges[i])
        foreach (edges[j])
          do_op(3'(o), edges[i], edges[j]);
    // random
    for (int n = 0; n < 3000; n++)
      do_op(3'($urandom_range(0, 7)), $urandom, $urandom);
    // random small divisors / dividends
    for (int n = 0; n < 500; n++)
      do_op(3'($urandom_range(4, 7)), $urandom, 32'($urandom_range(0, 16)) - 32'd8);
    // result held while EX is stalled by MEM
    for (int n = 0; n < 50; n++)
      do_op(3'($urandom_range(0, 7)), $urandom, $urandom, $urandom_range(1, 5));
    // abort in the middle of a division, then a normal operation must be correct
    for (int n = 0; n < 50; n++) begin
      abort_div($urandom_range(0, 34));
      do_op(3'($urandom_range(4, 7)), $urandom, $urandom | 32'h1);
    end
    `CHECK(max_lat >= 32 && max_lat <= 34, $sformatf("divide latency %0d not in 32..34", max_lat))
    $display("[tb_muldiv] max divide latency (cycles not ready) = %0d", max_lat);
    `TB_FINISH
  end
endmodule
