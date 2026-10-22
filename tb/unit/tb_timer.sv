// tb_timer.sv - TIMER64: reset values, mtime counting with PRESCALE and EN,
// 64-bit carry, write precedence, mtimecmp compare (mtip level) including the
// glitch-free LO/HI update sequence, msip, PSLVERR, byte writes.
`timescale 1ns/1ps
`include "tb_common.svh"

module tb_timer;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        psel, penable, pwrite, pready, pslverr, mtip, msip;
  logic [11:0] paddr;
  logic [31:0] pwdata, prdata, rd, rd2;
  logic [3:0]  pstrb;
  logic [63:0] mtime;
  logic        err;

  always #5 clk = ~clk;

  timer64_apb dut (.clk, .rst_n, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
                   .pready, .pslverr, .mtime, .mtip, .msip);
  apb_master_bfm apb (.clk, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
                      .pready, .pslverr);

  localparam logic [11:0] LO = 12'h00, HI = 12'h04, CLO = 12'h08, CHI = 12'h0C, CTRL = 12'h10,
                          MSIP = 12'h14;

  task automatic rd_check(input logic [11:0] a, input logic [31:0] exp, input string what);
    apb.apb_read(a, rd, err);
    `CHECK(!err && rd === exp, $sformatf("%s: %08x exp %08x", what, rd, exp))
  endtask

  // glitch-free mtimecmp update (Privileged spec, RV32)
  task automatic set_cmp(input logic [63:0] v);
    apb.apb_write(CLO, 32'hFFFF_FFFF);
    apb.apb_write(CHI, v[63:32]);
    apb.apb_write(CLO, v[31:0]);
  endtask

  int mtip_glitch = 0;
  bit watch = 0;
  always @(posedge clk) if (watch && mtip) mtip_glitch++;

  `TB_TIMEOUT(20ms)

  initial begin
    logic [63:0] t0, t1;
    `TB_INIT
    repeat (2) @(posedge clk);
    rst_n = 1;
    rd_check(CLO, 32'hFFFF_FFFF, "MTIMECMP_LO reset");
    rd_check(CHI, 32'hFFFF_FFFF, "MTIMECMP_HI reset");
    rd_check(CTRL, 32'h1, "CTRL reset (EN=1, PRESCALE=0)");
    rd_check(MSIP, 32'h0, "MSIP reset");
    `CHECK(!mtip && !msip, "no interrupts after reset")
    apb.apb_read(12'h018, rd, err); `CHECK(err, "PSLVERR 0x18")

    // counting with PRESCALE = 0: +1 per clock
    t0 = mtime; repeat (100) @(posedge clk); #1; t1 = mtime;
    `CHECK(t1 - t0 == 100, $sformatf("PRESCALE 0: delta %0d", t1 - t0))
    // PRESCALE = 4: +1 every 5 clocks
    apb.apb_write(CTRL, 32'h0000_0401);
    @(posedge clk); #1; t0 = mtime; repeat (500) @(posedge clk); #1; t1 = mtime;
    `CHECK(t1 - t0 == 100, $sformatf("PRESCALE 4: delta %0d", t1 - t0))
    // EN = 0 stops the counter
    apb.apb_write(CTRL, 32'h0000_0000);
    t0 = mtime; repeat (50) @(posedge clk); #1;
    `CHECK(mtime == t0, "EN=0 stops mtime")
    // write MTIME with byte strobes; 64-bit carry
    apb.apb_write(LO, 32'hFFFF_FFF0);
    apb.apb_write(HI, 32'h0000_0007);
    apb.apb_write(HI, 32'hAB00_0000, 4'b1000);
    rd_check(HI, 32'hAB00_0007, "MTIME_HI byte write");
    rd_check(LO, 32'hFFFF_FFF0, "MTIME_LO");
    apb.apb_write(CTRL, 32'h1);
    repeat (40) @(posedge clk);
    // hi-lo-hi read loop
    do begin
      apb.apb_read(HI, rd, err);
      apb.apb_read(LO, rd2, err);
      apb.apb_read(HI, t0[63:32], err);
    end while (rd != t0[63:32]);
    `CHECK(rd == 32'hAB00_0008, $sformatf("carry into MTIME_HI: %08x", rd))
    // compare: mtip asserts exactly when mtime >= mtimecmp
    apb.apb_write(CTRL, 32'h0);
    apb.apb_write(HI, 0); apb.apb_write(LO, 32'h0000_1000);
    watch = 1;
    set_cmp(64'h0000_0001_0000_0000);  // must not glitch while updating
    watch = 0;
    `CHECK(mtip_glitch == 0, $sformatf("mtimecmp update glitched mtip %0d times", mtip_glitch))
    set_cmp(64'h0000_0000_0000_1100);
    `CHECK(!mtip, "mtime < mtimecmp")
    apb.apb_write(CTRL, 32'h1);
    wait (mtip);
    #1;
    `CHECK(mtime == 64'h1100, $sformatf("mtip at mtime=%0h", mtime))
    repeat (10) @(posedge clk);
    `CHECK(mtip, "mtip is a level")
    set_cmp(mtime + 64'd1000);
    `CHECK(!mtip, "mtip cleared by a new mtimecmp")
    // msip
    apb.apb_write(MSIP, 32'h1);  `CHECK(msip, "msip set")
    rd_check(MSIP, 1, "MSIP read");
    apb.apb_write(MSIP, 32'h0);  `CHECK(!msip, "msip cleared")
    // random compare checks
    for (int n = 0; n < 200; n++) begin
      logic [63:0] c;
      apb.apb_write(CTRL, 32'h0);
      c = {32'($urandom_range(0, 2)), $urandom};
      set_cmp(c);
      apb.apb_write(HI, 32'($urandom_range(0, 2)));
      apb.apb_write(LO, $urandom);
      #1;
      `CHECK(mtip == (mtime >= c), $sformatf("compare mtime=%h cmp=%h mtip=%0d", mtime, c, mtip))
    end
    `TB_FINISH
  end
endmodule
