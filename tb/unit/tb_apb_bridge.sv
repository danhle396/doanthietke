`timescale 1ns/1ps
`include "tb_common.svh"

module tb_apb_bridge;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  logic        s_req, s_we, s_ready, s_err;
  logic [3:0]  s_be;
  logic [31:0] s_addr, s_wdata, s_rdata;
  logic        wb_ack, wb_err;
  logic [31:0] paddr, pwdata, prdata;
  logic [15:0] psel;
  logic        penable, pwrite, pready, pslverr;
  logic [3:0]  pstrb, slot;
  logic [2:0]  pprot;

  always #5 clk = ~clk;

  apb_bridge #(.SLOT_MASK(16'h0005)) dut (
    .clk, .rst_n,
    .wb_cyc_i(s_req), .wb_stb_i(s_req), .wb_we_i(s_we), .wb_sel_i(s_be), .wb_adr_i(s_addr),
    .wb_dat_i(s_wdata), .wb_dat_o(s_rdata), .wb_ack_o(wb_ack), .wb_err_o(wb_err),
    .paddr, .psel, .penable, .pwrite, .pwdata, .pstrb, .pprot, .prdata, .pready, .pslverr, .slot);

  assign s_ready = wb_ack || wb_err;
  assign s_err   = wb_err;

  wb_checker #(.NAME("apb_bridge")) u_wbchk (
    .clk, .rst_n, .cyc(s_req), .stb(s_req), .we(s_we), .sel(s_be), .adr(s_addr), .dat_w(s_wdata),
    .ack(wb_ack), .err(wb_err));

  logic [31:0] rd0, rd2;
  logic        rdy0, rdy2, err0, err2;
  apb_slave_model #(.MAX_WAIT(3)) s0 (.clk, .rst_n, .psel(psel[0]), .penable, .pwrite,
    .paddr(paddr[11:0]), .pwdata, .pstrb, .prdata(rd0), .pready(rdy0), .pslverr(err0));
  apb_slave_model #(.MAX_WAIT(0)) s2 (.clk, .rst_n, .psel(psel[2]), .penable, .pwrite,
    .paddr(paddr[11:0]), .pwdata, .pstrb, .prdata(rd2), .pready(rdy2), .pslverr(err2));

  always_comb begin
    case (slot)
      4'd0:    begin prdata = rd0; pready = rdy0; pslverr = err0; end
      4'd2:    begin prdata = rd2; pready = rdy2; pslverr = err2; end
      default: begin prdata = 32'h0; pready = 1'b1; pslverr = 1'b1; end
    endcase
  end

  // protocol monitor
  int proto_err = 0;
  always @(posedge clk) begin
    if (rst_n) begin
      if (!$onehot0(psel)) proto_err++;
      if (penable && psel == 0 && slot inside {4'd0, 4'd2}) proto_err++;
      if (pprot != 3'b000) proto_err++;
      if (psel != 0 && !(slot inside {4'd0, 4'd2})) proto_err++;  // empty slot selected
    end
  end

  logic [31:0] model [2][1024];
  int min_lat = 1000;

  task automatic access(input logic we, input logic [31:0] addr, input logic [31:0] wd,
                        input logic [3:0] be, output logic [31:0] rdata, output logic err);
    int lat = 0;
    @(negedge clk);
    s_req = 1; s_we = we; s_addr = addr; s_wdata = wd; s_be = be;
    // sample mid-cycle; the transfer completes at the next rising edge
    forever begin
      lat++;
      #1;
      if (s_ready) begin
        rdata = s_rdata;
        err = s_err;
        @(posedge clk);
        break;
      end
      if (lat > 50) begin
        `CHECK(0, "bridge never answered")
        break;
      end
      @(negedge clk);
    end
    if (lat < min_lat) min_lat = lat;
    @(negedge clk);
    s_req = 0;
  endtask

  `TB_TIMEOUT(20ms)

  initial begin
    logic [31:0] rd, exp;
    logic        err;
    `TB_INIT
    s_req = 0; s_we = 0; s_be = 0; s_addr = 0; s_wdata = 0;
    foreach (model[i, j]) model[i][j] = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;

    // directed: write/read both slots, byte enables
    access(1, 32'h1000_0010, 32'hDEAD_BEEF, 4'hF, rd, err);  `CHECK(!err, "write slot0")
    model[0][4] = 32'hDEAD_BEEF;
    access(0, 32'h1000_0010, 0, 4'hF, rd, err);
    `CHECK(!err && rd == 32'hDEAD_BEEF, $sformatf("read slot0 %08x", rd))
    access(1, 32'h1000_2020, 32'h1122_3344, 4'b0101, rd, err);
    model[1][8] = 32'h0022_0044;
    access(0, 32'h1000_2020, 0, 4'hF, rd, err);
    `CHECK(!err && rd == 32'h0022_0044, $sformatf("byte-enable write slot2 %08x", rd))
    // PSLVERR from a slave
    access(0, 32'h1000_0FFC, 0, 4'hF, rd, err);  `CHECK(err, "PSLVERR read slot0")
    access(1, 32'h1000_2FFC, 1, 4'hF, rd, err);  `CHECK(err, "PSLVERR write slot2")
    // empty slots
    for (int sl = 0; sl < 16; sl++) if (sl != 0 && sl != 2) begin
      access(0, 32'h1000_0000 + 32'(sl << 12), 0, 4'hF, rd, err);
      `CHECK(err, $sformatf("empty slot %0d must return err", sl))
      access(1, 32'h1000_0004 + 32'(sl << 12), 32'h5, 4'hF, rd, err);
      `CHECK(err, $sformatf("empty slot %0d write must return err", sl))
    end
    // random traffic
    for (int n = 0; n < 3000; n++) begin
      int sidx, w;
      logic [31:0] addr, wd;
      logic [3:0] be;
      sidx = $urandom_range(0, 1);
      w = $urandom_range(0, 254);
      addr = 32'h1000_0000 + 32'(sidx * 32'h2000) + 32'(w * 4);
      wd = $urandom;
      be = 4'($urandom_range(1, 15));
      if ($urandom_range(0, 1)) begin
        access(1, addr, wd, be, rd, err);
        `CHECK(!err, "random write err")
        for (int b = 0; b < 4; b++) if (be[b]) model[sidx][w][b*8 +: 8] = wd[b*8 +: 8];
      end else begin
        access(0, addr, 0, 4'hF, rd, err);
        `CHECK(!err && rd == model[sidx][w],
               $sformatf("random read %08x got %08x exp %08x", addr, rd, model[sidx][w]))
      end
    end
    `CHECK(min_lat == 3, $sformatf("minimum latency %0d (expected 3)", min_lat))
    `CHECK(s0.violations == 0 && s2.violations == 0,
           $sformatf("slave protocol violations %0d/%0d", s0.violations, s2.violations))
    `CHECK(proto_err == 0, $sformatf("bridge protocol errors %0d", proto_err))
    `CHECK(u_wbchk.violations == 0, $sformatf("Wishbone violations %0d", u_wbchk.violations))
    `CHECK(s0.waits_total > 0, "no wait states were exercised")
    $display("[tb_apb_bridge] accesses slot0=%0d slot2=%0d, wait cycles=%0d",
             s0.accesses, s2.accesses, s0.waits_total);
    `TB_FINISH
  end
endmodule
