`timescale 1ns/1ps

module tb_soc #(
  parameter bit ENABLE_M    = 1'b1,
  parameter bit ENABLE_C    = 1'b1,
  parameter int BP_MODE     = 2,
  parameter int BHT_ENTRIES = 256,
  parameter int BTB_ENTRIES = 32,
  parameter bit CORE_SC     = 1'b0,
  parameter int RAM_DEPTH   = 32768,
  parameter bit RAM_SYNC    = 1'b0
);

  logic        clk = 1'b0;
  logic        rst_n = 1'b0;
  logic        uart_tx, uart_rx;
  logic        spi_sclk, spi_mosi, spi_miso;
  logic [3:0]  spi_cs_n;
  logic [15:0] gpio_i, gpio_o, gpio_oe;

  always #10 clk = ~clk;  // 50 MHz

  soc_top #(
    .ENABLE_M(ENABLE_M), .ENABLE_C(ENABLE_C), .BP_MODE(BP_MODE),
    .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES), .CORE_SC(CORE_SC),
    .RAM_DEPTH(RAM_DEPTH), .RAM_SYNC(RAM_SYNC)
  ) dut (
    .clk, .rst_n,
    .uart_tx, .uart_rx,
    .spi_sclk, .spi_mosi, .spi_miso, .spi_cs_n,
    .gpio_i, .gpio_o, .gpio_oe
  );

  // ---------------- Bus functional models ----------------
`include "tb_soc_bfms.svh"

  // ---------------- Wishbone protocol checkers ----------------
  wb_checker #(.NAME("ibus")) u_wbchk_ibus (
    .clk, .rst_n(dut.rst_sn), .cyc(dut.ibus_cyc), .stb(dut.ibus_stb), .we(1'b0), .sel(4'hF),
    .adr(dut.ibus_adr), .dat_w(32'b0), .ack(dut.ibus_ack), .err(dut.ibus_err));
  wb_checker #(.NAME("dbus")) u_wbchk_dbus (
    .clk, .rst_n(dut.rst_sn), .cyc(dut.dbus_cyc), .stb(dut.dbus_stb), .we(dut.dbus_we),
    .sel(dut.dbus_sel), .adr(dut.dbus_adr), .dat_w(dut.dbus_wdat), .ack(dut.dbus_ack),
    .err(dut.dbus_err));
  wb_checker #(.NAME("ram")) u_wbchk_ram (
    .clk, .rst_n(dut.rst_sn), .cyc(dut.ram_cyc), .stb(dut.ram_stb), .we(dut.ram_we),
    .sel(dut.ram_sel), .adr(dut.ram_adr), .dat_w(dut.ram_wdat), .ack(dut.ram_ack), .err(1'b0));
  wb_checker #(.NAME("apb_bridge")) u_wbchk_apb (
    .clk, .rst_n(dut.rst_sn), .cyc(dut.br_cyc), .stb(dut.br_stb), .we(dut.br_we),
    .sel(dut.br_sel), .adr(dut.br_adr), .dat_w(dut.br_wdat), .ack(dut.br_ack), .err(dut.br_err));

  task automatic wb_final_check(inout bit pass, inout string why);
    int unsigned v;
    v = u_wbchk_ibus.violations + u_wbchk_dbus.violations + u_wbchk_ram.violations +
        u_wbchk_apb.violations;
    $display("[wb] ibus fetch=%0d err=%0d | dbus ack=%0d err=%0d wait=%0d | ram ack=%0d | apb_bridge ack=%0d err=%0d wait=%0d | violations=%0d",
             u_wbchk_ibus.transfers, u_wbchk_ibus.errors, u_wbchk_dbus.transfers,
             u_wbchk_dbus.errors, u_wbchk_dbus.wait_cycles, u_wbchk_ram.transfers,
             u_wbchk_apb.transfers, u_wbchk_apb.errors, u_wbchk_apb.wait_cycles, v);
    if (v != 0 && pass) begin
      pass = 1'b0;
      why  = $sformatf("%0d Wishbone protocol violations", v);
    end
  endtask

  // ---------------- Performance observation ----------------
  logic [63:0] obs_mcycle, obs_minstret;
  logic [63:0] obs_hpm [3:10];
  logic        obs_id_redirect, obs_ex_redirect, obs_md_abort, obs_irq_taken;
  logic        obs_irq_wait_div, obs_irq_cancel_div;

  if (CORE_SC) begin : g_obs_sc
    assign obs_mcycle      = dut.g_sc.u_core.u_csr.mcycle_q;
    assign obs_minstret    = dut.g_sc.u_core.u_csr.minstret_q;
    for (genvar i = 3; i <= 10; i++) begin : g_h
      assign obs_hpm[i] = dut.g_sc.u_core.u_csr.hpm_q[i];
    end
    assign obs_id_redirect = 1'b0;
    assign obs_ex_redirect = 1'b0;
    assign obs_md_abort    = 1'b0;
    assign obs_irq_taken   = dut.g_sc.u_core.trap && dut.g_sc.u_core.take_irq;
    assign obs_irq_wait_div   = 1'b0;
    assign obs_irq_cancel_div = 1'b0;
  end else begin : g_obs_pipe
    assign obs_mcycle      = dut.g_pipe.u_core.u_csr.mcycle_q;
    assign obs_minstret    = dut.g_pipe.u_core.u_csr.minstret_q;
    for (genvar i = 3; i <= 10; i++) begin : g_h
      assign obs_hpm[i] = dut.g_pipe.u_core.u_csr.hpm_q[i];
    end
    assign obs_id_redirect = dut.g_pipe.u_core.id_redirect;
    assign obs_ex_redirect = dut.g_pipe.u_core.ex_redirect;
    // divider killed while iterating (e.g. interrupt during DIV)
    assign obs_md_abort    = dut.g_pipe.u_core.mem_redirect && dut.g_pipe.u_core.md_busy;
    assign obs_irq_taken   = dut.g_pipe.u_core.u_mem.trap_irq;
    // an enabled interrupt is pending while the divider iterates
    assign obs_irq_wait_div = dut.g_pipe.u_core.irq_req && dut.g_pipe.u_core.md_busy;
    // an interrupt cancels a DIV/REM that reached MEM (re-executed after MRET)
    assign obs_irq_cancel_div = dut.g_pipe.u_core.u_mem.trap_irq &&
        (dut.g_pipe.u_core.mem_insn[6:0] == 7'b0110011) &&
        (dut.g_pipe.u_core.mem_insn[31:25] == 7'b0000001) && dut.g_pipe.u_core.mem_insn[14] &&
        !dut.g_pipe.u_core.mem_is_c;
  end

  longint unsigned cycle_cnt = 0;
  longint unsigned id_redirects = 0;
  longint unsigned ex_redirects = 0;
  longint unsigned md_aborts = 0;
  longint unsigned irqs_taken = 0;
  longint unsigned irq_wait_div = 0;
  longint unsigned irq_cancel_div = 0;
  logic            wait_div_d = 0;

  always @(posedge clk) begin
    if (rst_n) begin
      cycle_cnt <= cycle_cnt + 1;
      if (obs_id_redirect) id_redirects <= id_redirects + 1;
      if (obs_ex_redirect) ex_redirects <= ex_redirects + 1;
      if (obs_md_abort)    md_aborts <= md_aborts + 1;
      if (obs_irq_taken)   irqs_taken <= irqs_taken + 1;
      wait_div_d <= obs_irq_wait_div;
      if (obs_irq_wait_div && !wait_div_d) irq_wait_div <= irq_wait_div + 1;
      if (obs_irq_cancel_div) irq_cancel_div <= irq_cancel_div + 1;
    end
  end

  task automatic print_perf();
    longint unsigned cpi_x1000;
    cpi_x1000 = (obs_minstret != 0) ? (cycle_cnt * 1000) / obs_minstret : 0;
    $display("[perf] cycles=%0d mcycle=%0d minstret=%0d cpi_x1000=%0d",
             cycle_cnt, obs_mcycle, obs_minstret, cpi_x1000);
    $display("[perf] branch=%0d branch_miss=%0d jump=%0d jump_miss=%0d",
             obs_hpm[3], obs_hpm[4], obs_hpm[5], obs_hpm[6]);
    $display("[perf] stall_load_use=%0d stall_muldiv=%0d stall_bus=%0d compressed=%0d",
             obs_hpm[7], obs_hpm[8], obs_hpm[9], obs_hpm[10]);
    $display("[perf] id_redirects=%0d ex_redirects=%0d md_aborts=%0d irqs=%0d irq_wait_div=%0d irq_cancel_div=%0d",
             id_redirects, ex_redirects, md_aborts, irqs_taken, irq_wait_div, irq_cancel_div);
  endtask

  // ---------------- End-of-test handling ----------------
  logic [31:0] tohost_addr = 32'hFFFF_FFFF;
  longint unsigned max_cycles = 2000000;
  bit   finished = 0;
  string trace_file;

  task automatic finish_test(input bit pass_in, input string why_in);
    bit    pass = pass_in;
    string why  = why_in;
    if (finished) return;
    finished = 1;
    repeat (8) @(posedge clk);  // let WB print the last commits
    bfm_final_check(pass, why);
    wb_final_check(pass, why);
    print_perf();
    if (pass) begin
      $display("PASS");
      $finish;
    end else begin
      $display("FAIL: %s", why);
      $fatal(1, "FAIL: %s", why);
    end
  endtask

  initial begin
    int seed;
    if ($value$plusargs("tohost=%h", tohost_addr)) ;
    if ($value$plusargs("max_cycles=%d", max_cycles)) ;
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    $display("[tb_soc] config M=%0d C=%0d BP=%0d BHT=%0d BTB=%0d SC=%0d seed=%0d tohost=%08x",
             ENABLE_M, ENABLE_C, BP_MODE, BHT_ENTRIES, BTB_ENTRIES, CORE_SC, seed, tohost_addr);
    if ($test$plusargs("trace")) begin
      if (!$value$plusargs("trace_file=%s", trace_file)) trace_file = "tb_soc.fst";
      $dumpfile(trace_file);
      $dumpvars(0, tb_soc);
    end
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
  end

  // End events: capture the reason now, finish in a separate process.
  bit    end_pass;
  string end_why;

  always @(posedge clk) begin
    if (rst_n && !finished) begin
      if (dut.dbus_cyc && dut.dbus_stb && dut.dbus_we && dut.dbus_ack &&
          dut.dbus_adr == tohost_addr && dut.dbus_wdat[0]) begin
        // tohost: code = value >> 1, 0 = PASS
        end_pass = ((dut.dbus_wdat >> 1) == 0);
        end_why  = end_pass ? "tohost" : $sformatf("tohost code %0d", dut.dbus_wdat >> 1);
        fork finish_test(end_pass, end_why); join_none
      end else if (dut.u_sim.exit_req_q) begin
        end_pass = (dut.u_sim.exit_code_q == 0);
        end_why  = end_pass ? "exit" : $sformatf("exit code %0d", dut.u_sim.exit_code_q);
        fork finish_test(end_pass, end_why); join_none
      end else if (cycle_cnt >= max_cycles) begin
        end_pass = 1'b0;
        end_why  = $sformatf("timeout after %0d cycles", cycle_cnt);
        fork finish_test(end_pass, end_why); join_none
      end
    end
  end

endmodule
