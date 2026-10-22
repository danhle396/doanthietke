// tb_spi.sv - SPI master peripheral.
//   * register reset values, PSLVERR
//   * 4 modes x MSB/LSB first x CLK_DIV {0, 1, 5}: random bytes exchanged
//     with spi_slave_bfm (MOSI checked at the slave, MISO checked through
//     the RX FIFO), SCLK half period = CLK_DIV + 1, idle level = CPOL
//   * DONE interrupt (sticky, W1C), RX_NOT_EMPTY / TX_EMPTY levels, BUSY
//   * RX overrun (17 bytes, no reads) and W1C clear
//   * spi_flash_bfm on CS0: JEDEC ID in mode 0 and mode 3, READ
`timescale 1ns/1ps
`include "tb_common.svh"

module tb_spi;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        psel, penable, pwrite, pready, pslverr, irq;
  logic [11:0] paddr;
  logic [31:0] pwdata, prdata, rd;
  logic [3:0]  pstrb, cs_n;
  logic        err, sclk, mosi, miso, miso_slave, miso_flash;

  always #5 clk = ~clk;

  spi_apb dut (.clk, .rst_n, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
               .pready, .pslverr, .spi_sclk(sclk), .spi_mosi(mosi), .spi_miso(miso),
               .spi_cs_n(cs_n), .irq);
  apb_master_bfm apb (.clk, .psel, .penable, .pwrite, .paddr, .pwdata, .pstrb, .prdata,
                      .pready, .pslverr);
  spi_slave_bfm slave (.sclk, .mosi, .cs_n(cs_n[1]), .miso(miso_slave));
  spi_flash_bfm #(.T_PP_NS(2000), .T_SE_NS(4000)) flash (.sclk, .mosi, .cs_n(cs_n[0]),
                                                         .miso(miso_flash));

  assign miso = !cs_n[0] ? miso_flash : (!cs_n[1] ? miso_slave : 1'b0);

  localparam logic [11:0] DATA = 12'h00, STATUS = 12'h04, CTRL = 12'h08, DIV = 12'h0C,
                          CS = 12'h10, IRQ_EN = 12'h14, IRQ_ST = 12'h18;

  // SCLK half-period monitor (only while a CS is active)
  int last_edge_cycle = -1, cyc = 0, expected_half = 1, half_err = 0, n_edges = 0;
  logic sclk_d;
  always @(posedge clk) begin
    cyc++;
    sclk_d <= sclk;
    if (sclk !== sclk_d && cs_n != 4'hF) begin
      if (last_edge_cycle >= 0 && (cyc - last_edge_cycle) != expected_half &&
          (cyc - last_edge_cycle) < 2 * expected_half) half_err++;
      last_edge_cycle = cyc;
      n_edges++;
    end
  end

  task automatic rd_check(input logic [11:0] a, input logic [31:0] mask, input logic [31:0] exp,
                          input string what);
    apb.apb_read(a, rd, err);
    `CHECK(!err && (rd & mask) === exp, $sformatf("%s: %08x exp %08x", what, rd & mask, exp))
  endtask

  task automatic wait_done();
    int n = 0;
    do begin
      apb.apb_read(STATUS, rd, err);
      n++;
    end while ((rd[4] || !rd[1]) && n < 100000);  // BUSY or TX not empty
    `CHECK(n < 100000, "SPI transfer did not finish")
  endtask

  // exchange `n` random bytes with the slave in the given mode
  task automatic xfer_slave(input int mode, input bit lsb, input int div, input int n);
    byte sent[$];
    slave.cpol = mode[1]; slave.cpha = mode[0]; slave.lsb_first = lsb;
    slave.rx_q.delete(); slave.tx_log.delete();
    apb.apb_write(DIV, 32'(div));
    apb.apb_write(CTRL, {28'b0, lsb, 1'(mode[0]), 1'(mode[1]), 1'b1});
    expected_half = div + 1;
    last_edge_cycle = -1;
    apb.idle(4);
    `CHECK(sclk == 1'(mode[1]), $sformatf("idle SCLK level for mode %0d", mode))
    apb.apb_write(CS, 32'hD);                 // assert CS1
    for (int i = 0; i < n; i++) begin
      byte b;
      b = 8'($urandom);
      sent.push_back(b);
      apb.apb_write(DATA, {24'b0, b});
    end
    wait_done();
    apb.apb_write(CS, 32'hF);
    `CHECK(slave.rx_q.size() == n, $sformatf("mode %0d lsb %0d div %0d: slave got %0d bytes", mode, lsb, div, slave.rx_q.size()))
    for (int i = 0; i < n; i++) begin
      apb.apb_read(DATA, rd, err);
      if (i < slave.rx_q.size())
        `CHECK(slave.rx_q[i] == sent[i], $sformatf("mode %0d lsb %0d div %0d MOSI byte %0d: %02x exp %02x", mode, lsb, div, i, slave.rx_q[i], sent[i]))
      `CHECK(!rd[31] && rd[7:0] == slave.tx_log[i], $sformatf("mode %0d lsb %0d div %0d MISO byte %0d: %02x exp %02x", mode, lsb, div, i, rd[7:0], slave.tx_log[i]))
    end
  endtask

  task automatic flash_cmd(input logic [7:0] cmd_bytes[$], input int n_read, output byte rx_bytes[$]);
    apb.apb_write(CS, 32'hE);
    foreach (cmd_bytes[i]) apb.apb_write(DATA, {24'b0, cmd_bytes[i]});
    for (int i = 0; i < n_read; i++) apb.apb_write(DATA, 32'h0);
    wait_done();
    apb.apb_write(CS, 32'hF);
    rx_bytes.delete();
    for (int i = 0; i < cmd_bytes.size() + n_read; i++) begin
      apb.apb_read(DATA, rd, err);
      if (i >= cmd_bytes.size()) rx_bytes.push_back(rd[7:0]);
    end
  endtask

  `TB_TIMEOUT(500ms)

  initial begin
    byte r[$];
    `TB_INIT
    repeat (2) @(posedge clk);
    rst_n = 1;

    // ---------------- reset values ----------------
    rd_check(CTRL, 32'hFFFF_FFFF, 0, "CTRL reset");
    rd_check(DIV, 32'hFFFF_FFFF, 3, "CLK_DIV reset");
    rd_check(CS, 32'hFFFF_FFFF, 32'hF, "CS reset");
    rd_check(STATUS, 32'hFFFF_FFFF, 32'h6, "STATUS reset (TX_EMPTY, RX_EMPTY)");
    rd_check(IRQ_ST, 32'hF, 32'h1, "IRQ_STATUS reset (TX_EMPTY level)");
    apb.apb_read(12'h01C, rd, err);  `CHECK(err, "PSLVERR 0x1C")

    // ---------------- 4 modes x MSB/LSB x 3 dividers ----------------
    for (int mode = 0; mode < 4; mode++)
      for (int lsb = 0; lsb < 2; lsb++)
        for (int k = 0; k < 3; k++)
          xfer_slave(mode, 1'(lsb), (k == 0) ? 0 : (k == 1) ? 1 : 5, 6);
    `CHECK(half_err == 0, $sformatf("SCLK half period errors: %0d", half_err))
    `CHECK(n_edges > 0, "no SCLK edges seen")

    // ---------------- interrupts: DONE, RX_NOT_EMPTY ----------------
    apb.apb_write(CTRL, 32'h1);
    apb.apb_write(DIV, 32'h1);
    rd_check(IRQ_ST, 32'h4, 32'h4, "DONE left set by the previous transfers");
    apb.apb_write(IRQ_ST, 32'hC);              // W1C DONE/OVERRUN
    rd_check(IRQ_ST, 32'hC, 32'h0, "DONE cleared before the test");
    apb.apb_write(IRQ_EN, 32'h4);              // DONE
    apb.apb_write(CS, 32'hD);
    for (int i = 0; i < 3; i++) apb.apb_write(DATA, 32'h10 + 32'(i));
    rd_check(STATUS, 32'h10, 32'h10, "BUSY during transfer");
    `CHECK(!irq, "DONE not before the last byte")
    wait (irq);
    rd_check(STATUS, 32'h001F_0013, 32'h0003_0002, "RX_LEVEL=3, TX empty, not busy");
    rd_check(IRQ_ST, 32'hF, 32'h7, "IRQ_STATUS DONE | RX_NOT_EMPTY | TX_EMPTY");
    apb.apb_write(IRQ_ST, 32'h4);              // W1C DONE
    `CHECK(!irq, "DONE cleared")
    apb.apb_write(IRQ_EN, 32'h2);              // RX_NOT_EMPTY
    `CHECK(irq, "RX_NOT_EMPTY irq")
    for (int i = 0; i < 3; i++) apb.apb_read(DATA, rd, err);
    `CHECK(!irq, "RX_NOT_EMPTY cleared after reading")
    apb.apb_write(IRQ_EN, 32'h0);

    // ---------------- overrun ----------------
    apb.apb_write(DIV, 32'h0);
    for (int i = 0; i < 17; i++) apb.apb_write(DATA, 32'(i));
    wait_done();
    rd_check(STATUS, 32'h001F_0028, 32'h0010_0028, "RX_FULL, RX_OVERRUN, RX_LEVEL=16");
    rd_check(IRQ_ST, 32'h8, 32'h8, "IRQ_STATUS.OVERRUN");
    apb.apb_write(IRQ_ST, 32'h8);
    rd_check(STATUS, 32'h20, 0, "overrun cleared by W1C");
    for (int i = 0; i < 16; i++) apb.apb_read(DATA, rd, err);
    apb.apb_write(CS, 32'hF);

    // ---------------- flash on CS0: modes 0 and 3 ----------------
    for (int m = 0; m < 2; m++) begin
      apb.apb_write(CTRL, m ? 32'h7 : 32'h1);
      apb.apb_write(DIV, 32'h2);
      flash_cmd('{8'h9F}, 3, r);
      `CHECK(r.size() == 3 && r[0] == 8'hEF && r[1] == 8'h40 && r[2] == 8'h16,
             $sformatf("JEDEC ID mode %0d: %p", m ? 3 : 0, r))
      flash_cmd('{8'h03, 8'h00, 8'h00, 8'h10}, 4, r);
      for (int i = 0; i < 4; i++)
        `CHECK(r[i] == 8'(((16 + i) * 7 + 3) & 255), $sformatf("READ byte %0d mode %0d: %02x", i, m ? 3 : 0, r[i]))
    end
    `TB_FINISH
  end
endmodule
