`timescale 1ns/1ps
`include "tb_common.svh"

module tb_uart;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        psel, penable, pwrite, pready, pslverr, irq;
  logic [11:0] paddr;
  logic [31:0] pwdata, prdata, rd;
  logic [3:0]  pstrb;
  logic        err;
  logic        uart_tx, uart_rx, bfm_rx, loopback = 0, glitch = 0;

  always #5 clk = ~clk;

  assign uart_rx = loopback ? uart_tx : (bfm_rx & !glitch);

  uart_apb dut (.clk, .rst_n, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
                .pready, .pslverr, .uart_tx, .uart_rx, .irq);
  apb_master_bfm apb (.clk, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
                      .pready, .pslverr);
  uart_bfm bfm (.clk, .tx(uart_tx), .rx(bfm_rx));

  localparam logic [11:0] DATA = 12'h00, STATUS = 12'h04, CTRL = 12'h08, BAUD = 12'h0C,
                          IRQ_EN = 12'h10, IRQ_ST = 12'h14, WM = 12'h18;

  task automatic rd_check(input logic [11:0] a, input logic [31:0] mask, input logic [31:0] exp,
                          input string what);
    apb.apb_read(a, rd, err);
    `CHECK(!err && (rd & mask) === exp, $sformatf("%s: %08x (mask %08x) exp %08x", what, rd, mask, exp))
  endtask

  task automatic wait_status(input logic [31:0] mask, input logic [31:0] val, input int max_cycles);
    int n = 0;
    do begin
      apb.apb_read(STATUS, rd, err);
      n++;
    end while ((rd & mask) != val && n < max_cycles);
    `CHECK((rd & mask) == val, $sformatf("wait_status mask %08x val %08x: %08x", mask, val, rd))
  endtask

  task automatic set_format(input int div, input bit pen, input bit podd, input bit st2);
    apb.apb_write(BAUD, 32'(div));
    apb.apb_write(CTRL, {27'b0, st2, podd, pen, 2'b11});
    bfm.bit_cycles = 16 * (div + 1);
    bfm.parity_en = pen; bfm.parity_odd = podd; bfm.stop2 = st2;
  endtask

  task automatic drain_rx();
    do apb.apb_read(DATA, rd, err); while (!rd[31]);
  endtask

  `TB_TIMEOUT(500ms)

  initial begin
    byte sent[$];
    `TB_INIT
    bfm.echo = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;

    // ---------------- reset values ----------------
    rd_check(CTRL, 32'hFFFF_FFFF, 32'h3, "CTRL reset");
    rd_check(BAUD, 32'hFFFF_FFFF, 32'd26, "BAUD_DIV reset");
    rd_check(IRQ_EN, 32'hFFFF_FFFF, 0, "IRQ_EN reset");
    rd_check(WM, 32'hFFFF_FFFF, 32'h0001_0000, "WATERMARK reset");
    rd_check(STATUS, 32'hFFFF_FFFF, 32'h0000_000E, "STATUS reset (TX_EMPTY, TX_IDLE, RX_EMPTY)");
    rd_check(DATA, 32'h8000_0000, 32'h8000_0000, "DATA read when RX empty");
    apb.apb_read(12'h01C, rd, err);  `CHECK(err, "PSLVERR 0x1C")
    apb.apb_write(12'h100, 0);       `CHECK(apb.last_err, "PSLVERR 0x100")
    apb.apb_write(BAUD, 32'hFFFF_1234, 4'b0001);
    rd_check(BAUD, 32'hFFFF_FFFF, 32'h0000_0034, "BAUD byte write");

    // ---------------- loopback: every format x 3 baud rates ----------------
    loopback = 1;
    for (int d = 0; d < 3; d++) begin
      int div;
      div = (d == 0) ? 0 : (d == 1) ? 1 : 3;
      for (int f = 0; f < 6; f++) begin
        bit pen, podd, st2;
        pen = (f % 3) != 0; podd = (f % 3) == 2; st2 = f >= 3;
        set_format(div, pen, podd, st2);
        bfm.rx_q.delete();
        sent.delete();
        for (int i = 0; i < 12; i++) begin
          byte b;
          b = 8'($urandom);
          sent.push_back(b);
          apb.apb_write(DATA, {24'b0, b});
        end
        wait_status(32'h4, 32'h4, 20000);              // TX_IDLE
        repeat (bfm.bit_cycles) @(posedge clk);
        `CHECK(bfm.rx_q.size() == 12, $sformatf("fmt %0d div %0d: BFM got %0d bytes", f, div, bfm.rx_q.size()))
        for (int i = 0; i < 12; i++) begin
          apb.apb_read(DATA, rd, err);
          `CHECK(!rd[31] && rd[7:0] == sent[i], $sformatf("fmt %0d div %0d loopback byte %0d: %08x exp %02x", f, div, i, rd, sent[i]))
          if (i < bfm.rx_q.size())
            `CHECK(bfm.rx_q[i] == sent[i], $sformatf("fmt %0d BFM byte %0d", f, i))
        end
        rd_check(STATUS, 32'h0000_00E8, 32'h8, "no errors, RX empty after loopback");
        `CHECK(bfm.frame_errors == 0 && bfm.parity_errors == 0, "BFM saw frame/parity errors")
      end
    end
    loopback = 0;

    // ---------------- BFM -> RX: errors ----------------
    set_format(1, 1, 0, 0);
    apb.apb_write(IRQ_EN, 32'h4);                     // ERR interrupt
    bfm.send_byte(8'h5A);
    rd_check(DATA, 32'h8000_00FF, 32'h5A, "good byte from BFM");
    `CHECK(!irq, "no error irq for a good byte")
    bfm.send_byte(8'hA5, 1, 0);                       // parity error
    repeat (4) @(posedge clk);
    rd_check(STATUS, 32'h0000_00E0, 32'h80, "PARITY_ERR");
    `CHECK(irq, "ERR irq after parity error")
    rd_check(IRQ_ST, 32'h4, 32'h4, "IRQ_STATUS.ERR");
    apb.apb_write(IRQ_ST, 32'h4);                     // W1C
    rd_check(STATUS, 32'h0000_00E0, 0, "STATUS[7:5] cleared by W1C");
    `CHECK(!irq, "irq cleared")
    bfm.send_byte(8'h3C, 0, 1);                       // frame error (bad stop)
    repeat (4) @(posedge clk);
    rd_check(STATUS, 32'h0000_00E0, 32'h40, "FRAME_ERR");
    apb.apb_write(IRQ_ST, 32'h4);
    drain_rx();

    // false start: glitch shorter than half a bit
    @(negedge clk); glitch = 1; repeat (5) @(negedge clk); glitch = 0;
    repeat (bfm.bit_cycles * 12) @(posedge clk);
    rd_check(STATUS, 32'h0000_0008, 32'h8, "false start ignored (RX empty)");

    // ---------------- overrun ----------------
    set_format(0, 0, 0, 0);
    for (int i = 0; i < 17; i++) bfm.send_byte(8'(i + 1));
    repeat (4) @(posedge clk);
    rd_check(STATUS, 32'h001F_0030, 32'h0010_0030, "RX_FULL, RX_OVERRUN, RX_LEVEL=16");
    for (int i = 0; i < 16; i++) begin
      apb.apb_read(DATA, rd, err);
      `CHECK(rd[7:0] == 8'(i + 1), $sformatf("overrun keeps first 16 bytes (%0d: %02x)", i, rd[7:0]))
    end
    rd_check(IRQ_ST, 32'h4, 32'h4, "ERR set by overrun");
    apb.apb_write(IRQ_ST, 32'h4);
    rd_check(STATUS, 32'h20, 0, "overrun cleared");

    // ---------------- watermark interrupts ----------------
    apb.apb_write(IRQ_EN, 32'h2);                     // RX_WM
    apb.apb_write(WM, 32'h0004_0000);                 // RX_WM_LVL = 4
    for (int i = 0; i < 3; i++) bfm.send_byte(8'h40 + 8'(i));
    repeat (4) @(posedge clk);
    `CHECK(!irq, "RX_WM below level")
    bfm.send_byte(8'h43);
    repeat (4) @(posedge clk);
    `CHECK(irq, "RX_WM at level 4")
    drain_rx();
    `CHECK(!irq, "RX_WM cleared after draining")
    apb.apb_write(IRQ_EN, 32'h1);                     // TX_WM
    apb.apb_write(WM, 32'h0001_0002);                 // TX_WM_LVL = 2
    apb.apb_write(CTRL, 32'h2);                       // TX disabled: FIFO fills
    for (int i = 0; i < 5; i++) apb.apb_write(DATA, 32'h30 + 32'(i));
    `CHECK(!irq, "TX_WM: level 5 > 2")
    rd_check(STATUS, 32'h0000_1F07, 32'h0000_0500, "TX_LEVEL=5, not idle");
    apb.apb_write(CTRL, 32'h3);                       // enable TX: FIFO drains
    wait (irq);
    rd_check(STATUS, 32'h0000_1F00, 32'h0000_0200, "TX_WM fires at level 2");
    wait_status(32'h4, 32'h4, 20000);
    apb.apb_write(CTRL, 32'h2);                       // TX disabled
    for (int i = 0; i < 17; i++) apb.apb_write(DATA, 32'h61);  // 17th push is ignored
    rd_check(STATUS, 32'h0000_1F03, 32'h0000_1001, "TX_FULL, TX_LEVEL=16");
    `TB_FINISH
  end
endmodule
