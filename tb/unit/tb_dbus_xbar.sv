`timescale 1ns/1ps
`include "tb_common.svh"

module tb_dbus_xbar;
  `TB_DECLS

  localparam logic [31:0] RAM_BASE = 32'h8000_0000, RAM_SIZE = 32'h0000_1000;
  localparam logic [31:0] APB_BASE = 32'h1000_0000, APB_SIZE = 32'h0001_0000;

  logic        clk = 0, rst_n = 0;
  logic        m_cyc = 0, m_stb = 0, m_we = 0, m_ack, m_err;
  logic [3:0]  m_sel = 0;
  logic [31:0] m_adr = 0, m_wdat = 0, m_rdat;
  logic        r_cyc, r_stb, r_we, r_ack;
  logic [3:0]  r_sel;
  logic [31:0] r_adr, r_wdat, r_rdat;
  logic        a_cyc, a_stb, a_we, a_ack, a_err;
  logic [3:0]  a_sel;
  logic [31:0] a_adr, a_wdat, a_rdat;

  always #5 clk = ~clk;

  dbus_xbar #(.RAM_BASE(RAM_BASE), .RAM_SIZE(RAM_SIZE), .APB_BASE(APB_BASE),
              .APB_SIZE(APB_SIZE)) dut (
    .m_cyc_i(m_cyc), .m_stb_i(m_stb), .m_we_i(m_we), .m_sel_i(m_sel), .m_adr_i(m_adr),
    .m_dat_i(m_wdat), .m_dat_o(m_rdat), .m_ack_o(m_ack), .m_err_o(m_err),
    .ram_cyc_o(r_cyc), .ram_stb_o(r_stb), .ram_we_o(r_we), .ram_sel_o(r_sel),
    .ram_adr_o(r_adr), .ram_dat_o(r_wdat), .ram_dat_i(r_rdat), .ram_ack_i(r_ack),
    .apb_cyc_o(a_cyc), .apb_stb_o(a_stb), .apb_we_o(a_we), .apb_sel_o(a_sel),
    .apb_adr_o(a_adr), .apb_dat_o(a_wdat), .apb_dat_i(a_rdat), .apb_ack_i(a_ack),
    .apb_err_i(a_err));

  wb_checker #(.NAME("master")) u_chk_m (.clk, .rst_n, .cyc(m_cyc), .stb(m_stb), .we(m_we),
    .sel(m_sel), .adr(m_adr), .dat_w(m_wdat), .ack(m_ack), .err(m_err));
  wb_checker #(.NAME("ram")) u_chk_r (.clk, .rst_n, .cyc(r_cyc), .stb(r_stb), .we(r_we),
    .sel(r_sel), .adr(r_adr), .dat_w(r_wdat), .ack(r_ack), .err(1'b0));
  wb_checker #(.NAME("apb")) u_chk_a (.clk, .rst_n, .cyc(a_cyc), .stb(a_stb), .we(a_we),
    .sel(a_sel), .adr(a_adr), .dat_w(a_wdat), .ack(a_ack), .err(a_err));

  // ---------------- slave models ----------------
  logic [31:0] ram_mem [1024];
  logic [31:0] apb_mem [16384];

  assign r_ack  = r_cyc && r_stb;
  assign r_rdat = ram_mem[r_adr[11:2]];
  always @(posedge clk)
    if (r_cyc && r_stb && r_we)
      for (int b = 0; b < 4; b++) if (r_sel[b]) ram_mem[r_adr[11:2]][b*8 +: 8] <= r_wdat[b*8 +: 8];

  int a_wait = 0, a_cnt = 0, a_waits_total = 0;
  logic a_done;
  assign a_done = a_cyc && a_stb && (a_cnt >= a_wait);
  assign a_ack  = a_done && (a_adr[11:0] != 12'hFFC);
  assign a_err  = a_done && (a_adr[11:0] == 12'hFFC);
  assign a_rdat = apb_mem[a_adr[15:2]];
  always @(posedge clk) begin
    if (a_cyc && a_stb) begin
      if (a_done) begin
        if (a_we && a_ack)
          for (int b = 0; b < 4; b++) if (a_sel[b]) apb_mem[a_adr[15:2]][b*8 +: 8] <= a_wdat[b*8 +: 8];
        a_cnt  <= 0;
        a_wait <= $urandom_range(0, 3);
      end else begin
        a_cnt <= a_cnt + 1;
        a_waits_total++;
      end
    end
  end

  // routing monitor: only the decoded slave is selected, the rest is broadcast
  int route_err = 0;
  always @(posedge clk) begin
    if (rst_n) begin
      logic in_r, in_a;
      in_r = (m_adr >= RAM_BASE) && (m_adr - RAM_BASE < RAM_SIZE);
      in_a = (m_adr >= APB_BASE) && (m_adr - APB_BASE < APB_SIZE);
      if (r_stb != (m_stb && in_r) || a_stb != (m_stb && in_a)) route_err++;
      if (r_cyc != (m_cyc && in_r) || a_cyc != (m_cyc && in_a)) route_err++;
      if (r_adr != m_adr || a_adr != m_adr || r_wdat != m_wdat || a_wdat != m_wdat ||
          r_we != m_we || a_we != m_we || r_sel != m_sel || a_sel != m_sel) route_err++;
    end
  end

  // ---------------- master ----------------
  int lat_unmapped = -1;

  task automatic access(input logic we, input logic [31:0] adr, input logic [31:0] wd,
                        input logic [3:0] sel, output logic [31:0] rd, output logic err,
                        output int lat);
    @(negedge clk);
    m_cyc = 1; m_stb = 1; m_we = we; m_adr = adr; m_wdat = wd; m_sel = sel;
    lat = 0;
    forever begin
      #1;
      if (m_ack || m_err) break;
      lat++;
      if (lat > 20) begin `CHECK(0, "no ACK/ERR") break; end
      @(negedge clk);
    end
    rd = m_rdat;
    err = m_err;
    @(posedge clk);
    #1;
    m_cyc = 0; m_stb = 0;
  endtask

  `TB_TIMEOUT(20ms)

  initial begin
    logic [31:0] rd, adr, wd, exp;
    logic        err;
    int          lat, n_ram = 0, n_apb = 0, n_un = 0;
    logic [31:0] ram_model [1024];
    logic [31:0] apb_model [16384];
    `TB_INIT
    foreach (ram_mem[i])  begin ram_mem[i] = $urandom;  ram_model[i] = ram_mem[i]; end
    foreach (apb_mem[i])  begin apb_mem[i] = $urandom;  apb_model[i] = apb_mem[i]; end
    repeat (2) @(posedge clk);
    rst_n = 1;

    // directed: window borders and unmapped addresses
    access(0, RAM_BASE, 0, 4'hF, rd, err, lat);
    `CHECK(!err && rd == ram_model[0] && lat == 0, "RAM first word")
    access(0, RAM_BASE + RAM_SIZE - 4, 0, 4'hF, rd, err, lat);
    `CHECK(!err && rd == ram_model[1023], "RAM last word")
    access(0, RAM_BASE + RAM_SIZE, 0, 4'hF, rd, err, lat);
    `CHECK(err && lat == 0, "just above RAM must be ERR in the same cycle")
    access(0, RAM_BASE - 4, 0, 4'hF, rd, err, lat);    `CHECK(err, "just below RAM")
    access(0, APB_BASE, 0, 4'hF, rd, err, lat);        `CHECK(!err && rd == apb_model[0], "APB first word")
    access(1, APB_BASE + APB_SIZE, 5, 4'hF, rd, err, lat);
    `CHECK(err && lat == 0, "just above APB window must be ERR")
    access(1, APB_BASE + 32'h0FFC, 5, 4'hF, rd, err, lat); `CHECK(err, "APB slave ERR passed through")
    access(0, 32'h0000_0000, 0, 4'hF, rd, err, lat);   `CHECK(err, "address 0 unmapped")

    // random traffic
    for (int n = 0; n < 4000; n++) begin
      int region;
      logic we;
      logic [3:0] sel;
      region = $urandom_range(0, 9);
      we     = 1'($urandom_range(0, 1));
      sel    = we ? 4'($urandom_range(1, 15)) : 4'hF;
      wd     = $urandom;
      if (region < 5) begin           // RAM
        adr = RAM_BASE + 32'($urandom_range(0, 1023) * 4);
        access(we, adr, wd, sel, rd, err, lat);
        n_ram++;
        `CHECK(!err && lat == 0, $sformatf("RAM access %08x err=%0d lat=%0d", adr, err, lat))
        if (we) for (int b = 0; b < 4; b++) begin
          if (sel[b]) ram_model[adr[11:2]][b*8 +: 8] = wd[b*8 +: 8];
        end
        else `CHECK(rd == ram_model[adr[11:2]], $sformatf("RAM read %08x got %08x", adr, rd))
      end else if (region < 9) begin  // APB window (offset 0xFFC of each 4 KB -> ERR)
        adr = APB_BASE + 32'($urandom_range(0, 16383) * 4);
        access(we, adr, wd, sel, rd, err, lat);
        n_apb++;
        `CHECK(err == (adr[11:0] == 12'hFFC), $sformatf("APB access %08x err=%0d", adr, err))
        if (!err) begin
          if (we) for (int b = 0; b < 4; b++) begin
            if (sel[b]) apb_model[adr[15:2]][b*8 +: 8] = wd[b*8 +: 8];
          end
          else `CHECK(rd == apb_model[adr[15:2]], $sformatf("APB read %08x got %08x", adr, rd))
        end
      end else begin                   // unmapped
        do adr = {$urandom} & ~32'h3;
        while ((adr >= RAM_BASE && adr - RAM_BASE < RAM_SIZE) ||
               (adr >= APB_BASE && adr - APB_BASE < APB_SIZE));
        access(we, adr, wd, sel, rd, err, lat);
        n_un++;
        `CHECK(err && lat == 0 && rd == 0, $sformatf("unmapped %08x err=%0d lat=%0d", adr, err, lat))
      end
    end

    `CHECK(route_err == 0, $sformatf("routing errors %0d", route_err))
    `CHECK(u_chk_m.violations + u_chk_r.violations + u_chk_a.violations == 0,
           $sformatf("Wishbone violations %0d/%0d/%0d", u_chk_m.violations, u_chk_r.violations,
                     u_chk_a.violations))
    `CHECK(a_waits_total > 0, "no wait states were exercised")
    $display("[tb_dbus_xbar] ram=%0d apb=%0d unmapped=%0d, apb wait cycles=%0d, master ack=%0d err=%0d",
             n_ram, n_apb, n_un, a_waits_total, u_chk_m.transfers, u_chk_m.errors);
    `TB_FINISH
  end

endmodule
