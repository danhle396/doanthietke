// tb_gpio.sv - GPIO: register reset/RW, OUT/DIR to pins, 2-FF synchronized
// IN, rising/falling edge flags per pin, IRQ_EN masking, W1C, no spurious
// edge for pins already high at reset, random pin activity vs. a model.
`timescale 1ns/1ps
`include "tb_common.svh"

module tb_gpio;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        psel, penable, pwrite, pready, pslverr, irq;
  logic [11:0] paddr;
  logic [31:0] pwdata, prdata, rd;
  logic [3:0]  pstrb;
  logic [15:0] gpio_i, gpio_o, gpio_oe;
  logic        err;

  always #5 clk = ~clk;

  gpio_apb dut (.clk, .rst_n, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
                .pready, .pslverr, .gpio_i, .gpio_o, .gpio_oe, .irq);
  apb_master_bfm apb (.clk, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
                      .pready, .pslverr);

  localparam logic [11:0] OUT = 12'h00, IN = 12'h04, DIR = 12'h08, IEN = 12'h0C, IST = 12'h10,
                          ITYPE = 12'h14;

  task automatic rd_check(input logic [11:0] a, input logic [31:0] exp, input string what);
    apb.apb_read(a, rd, err);
    `CHECK(!err && rd === exp, $sformatf("%s: %08x exp %08x", what, rd, exp))
  endtask

  `TB_TIMEOUT(20ms)

  initial begin
    logic [15:0] model_st, typ, prev;
    `TB_INIT
    gpio_i = 16'h00F0;                    // some pins high during reset
    repeat (2) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);
    rd_check(IST, 0, "no spurious edge for pins high at reset");
    rd_check(IN, 32'h00F0, "IN synchronized");
    rd_check(OUT, 0, "OUT reset"); rd_check(DIR, 0, "DIR reset");
    rd_check(IEN, 0, "IRQ_EN reset"); rd_check(ITYPE, 0, "IRQ_TYPE reset");
    apb.apb_read(12'h018, rd, err); `CHECK(err, "PSLVERR 0x18")

    // outputs
    apb.apb_write(OUT, 32'hFFFF_A5C3);
    apb.apb_write(DIR, 32'h0000_FF00);
    `CHECK(gpio_o == 16'hA5C3 && gpio_oe == 16'hFF00, "OUT/DIR drive the pins")
    apb.apb_write(OUT, 32'h0000_7700, 4'b0010);
    rd_check(OUT, 32'h77C3, "OUT byte write");

    // IN synchronizer latency: visible after two clocks
    @(negedge clk); gpio_i = 16'h1234;
    @(posedge clk); #1;
    `CHECK(dut.in_q != 16'h1234, "IN must not change after 1 clock")
    @(posedge clk); #1;
    `CHECK(dut.in_q == 16'h1234, "IN after 2 clocks")

    // rising edges on pins with type 0, falling on type 1
    apb.apb_write(IST, 32'hFFFF);         // clear
    apb.apb_write(ITYPE, 32'h00FF);       // pins 0-7 falling, 8-15 rising
    @(negedge clk); gpio_i = 16'h0000;    // falling on pins 2,4,5 (0x1234 -> 0)
    repeat (4) @(posedge clk);
    rd_check(IST, 32'h0034, "falling edges on low byte");
    `CHECK(!irq, "IRQ_EN = 0 masks")
    apb.apb_write(IEN, 32'h0010);
    `CHECK(irq, "irq for pin 4")
    apb.apb_write(IST, 32'h0010);         // W1C pin 4
    rd_check(IST, 32'h0024, "W1C clears only pin 4");
    `CHECK(!irq, "irq cleared")
    @(negedge clk); gpio_i = 16'hFF00;    // rising on 8-15 (type 0)
    repeat (4) @(posedge clk);
    rd_check(IST, 32'hFF24, "rising edges on high byte");
    apb.apb_write(IST, 32'hFFFF);

    // random activity vs. model
    typ = 16'($urandom);
    apb.apb_write(ITYPE, {16'b0, typ});
    apb.apb_write(IEN, 32'hFFFF);
    prev = gpio_i;
    model_st = 0;
    for (int n = 0; n < 300; n++) begin
      logic [15:0] nv;
      nv = 16'($urandom);
      @(negedge clk); gpio_i = nv;
      repeat (4) @(posedge clk);
      for (int i = 0; i < 16; i++)
        if (typ[i] ? (prev[i] && !nv[i]) : (!prev[i] && nv[i])) model_st[i] = 1;
      prev = nv;
      apb.apb_read(IST, rd, err);
      `CHECK(rd[15:0] == model_st, $sformatf("random IRQ_STATUS %04x exp %04x", rd[15:0], model_st))
      `CHECK(irq == (model_st != 0), "random irq")
      if ($urandom_range(0, 1)) begin
        logic [15:0] c;
        c = 16'($urandom);
        apb.apb_write(IST, {16'b0, c});
        model_st &= ~c;
      end
    end
    `TB_FINISH
  end
endmodule
