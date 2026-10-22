// tb_intc.sv - INTC: register reset values, ENABLE read/write (with PSTRB),
// PENDING/ACTIVE follow the source levels, irq = |(PENDING & ENABLE) for every
// source/enable combination, PSLVERR on undefined offsets, random sequence.
`timescale 1ns/1ps
`include "tb_common.svh"

module tb_intc;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        psel, penable, pwrite, pready, pslverr, irq;
  logic [11:0] paddr;
  logic [31:0] pwdata, prdata, rd;
  logic [3:0]  pstrb;
  logic [2:0]  src;
  logic        err;

  always #5 clk = ~clk;

  intc_apb #(.N_SRC(3)) dut (.clk, .rst_n, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb,
                             .prdata, .pready, .pslverr, .src, .irq);
  apb_master_bfm apb (.clk, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb,
                      .prdata, .pready, .pslverr);

  task automatic rd_check(input logic [11:0] a, input logic [31:0] exp, input string what);
    apb.apb_read(a, rd, err);
    `CHECK(!err && rd === exp, $sformatf("%s: read %08x err=%0d exp %08x", what, rd, err, exp))
  endtask

  `TB_TIMEOUT(5ms)

  initial begin
    `TB_INIT
    src = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;
    rd_check(12'h004, 0, "ENABLE reset");
    rd_check(12'h000, 0, "PENDING reset");
    rd_check(12'h008, 0, "ACTIVE reset");
    `CHECK(!irq, "irq after reset")
    // exhaustive source x enable
    for (int e = 0; e < 8; e++) begin
      apb.apb_write(12'h004, 32'(e));
      rd_check(12'h004, 32'(e), "ENABLE");
      for (int s = 0; s < 8; s++) begin
        src = 3'(s);
        @(negedge clk);
        `CHECK(irq === |(3'(s) & 3'(e)), $sformatf("irq src=%0d en=%0d", s, e))
        rd_check(12'h000, 32'(s), "PENDING");
        rd_check(12'h008, 32'(s & e), "ACTIVE");
      end
    end
    // PSTRB[0] = 0: write ignored
    apb.apb_write(12'h004, 32'h0, 4'b1110);
    rd_check(12'h004, 32'h7, "ENABLE with pstrb[0]=0");
    // read-only registers ignore writes, upper bits read 0
    apb.apb_write(12'h000, 32'hFFFF_FFFF);
    apb.apb_write(12'h004, 32'hFFFF_FFFF);
    rd_check(12'h004, 32'h7, "ENABLE upper bits");
    // undefined offsets -> PSLVERR
    apb.apb_read(12'h00C, rd, err);  `CHECK(err, "PSLVERR @0x0C read")
    apb.apb_write(12'h010, 32'h1);   `CHECK(apb.last_err, "PSLVERR @0x10 write")
    apb.apb_read(12'hFFC, rd, err);  `CHECK(err, "PSLVERR @0xFFC read")
    // random
    for (int n = 0; n < 2000; n++) begin
      logic [2:0] e;
      e = 3'($urandom);
      if ($urandom_range(0, 3) == 0) apb.apb_write(12'h004, 32'(e));
      src = 3'($urandom);
      @(negedge clk);
      apb.apb_read(12'h004, rd, err);
      `CHECK(irq === |(src & rd[2:0]), "random irq")
    end
    `TB_FINISH
  end
endmodule
