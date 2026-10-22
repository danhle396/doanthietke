// ============================================================================
// tb_soc.sv - Single top-level testbench for riscv-tests, benchmarks and
//   system tests. All soc_top parameters are exposed (change with -G).
//
// Plusargs:
//   +hex=<file>          program image (read by ram_dp)
//   +tohost=<hex addr>   stop when the core stores to this address
//   +max_cycles=<n>      timeout (default 2,000,000) -> FAIL
//   +trace               dump FST waveform (+trace_file=<f>, default tb_soc.fst)
//   +commitlog=<file>    commit log (printed by wb_stage)
//   +console=<file>      SIM_CTRL PUTCHAR output copy
//   +uart_expect=<file>  expected UART TX text (checked at the end)
//   +uart_rx_file=<file> bytes the UART BFM sends into uart_rx
//   +seed=<n>            seed for randomized stimulus
// End of test: SIM_CTRL EXIT, tohost write, or timeout.
// ============================================================================
`timescale 1ns/1ps

module tb_soc #(
  parameter bit ENABLE_M    = 1'b1,
  parameter bit ENABLE_C    = 1'b1,
  parameter int BP_MODE     = 2,
  parameter int BHT_ENTRIES = 256,
  parameter int BTB_ENTRIES = 32,
  parameter bit CORE_SC     = 1'b0
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
    .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES), .CORE_SC(CORE_SC)
  ) dut (
    .clk, .rst_n,
    .uart_tx, .uart_rx,
    .spi_sclk, .spi_mosi, .spi_miso, .spi_cs_n,
    .gpio_i, .gpio_o, .gpio_oe
  );

  // ---------------- Bus functional models ----------------
`include "tb_soc_bfms.svh"

  // ---------------- Performance observation ----------------
  logic [63:0] obs_mcycle, obs_minstret;
  logic [63:0] obs_hpm [3:10];
  logic        obs_id_redirect, obs_ex_redirect;

  if (CORE_SC) begin : g_obs_sc
    assign obs_mcycle      = dut.g_sc.u_core.u_csr.mcycle_q;
    assign obs_minstret    = dut.g_sc.u_core.u_csr.minstret_q;
    for (genvar i = 3; i <= 10; i++) begin : g_h
      assign obs_hpm[i] = dut.g_sc.u_core.u_csr.hpm_q[i];
    end
    assign obs_id_redirect = 1'b0;
    assign obs_ex_redirect = 1'b0;
  end else begin : g_obs_pipe
    assign obs_mcycle      = dut.g_pipe.u_core.u_csr.mcycle_q;
    assign obs_minstret    = dut.g_pipe.u_core.u_csr.minstret_q;
    for (genvar i = 3; i <= 10; i++) begin : g_h
      assign obs_hpm[i] = dut.g_pipe.u_core.u_csr.hpm_q[i];
    end
    assign obs_id_redirect = dut.g_pipe.u_core.id_redirect;
    assign obs_ex_redirect = dut.g_pipe.u_core.ex_redirect;
  end

  longint unsigned cycle_cnt = 0;
  longint unsigned id_redirects = 0;
  longint unsigned ex_redirects = 0;

  always @(posedge clk) begin
    if (rst_n) begin
      cycle_cnt <= cycle_cnt + 1;
      if (obs_id_redirect) id_redirects <= id_redirects + 1;
      if (obs_ex_redirect) ex_redirects <= ex_redirects + 1;
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
    $display("[perf] id_redirects=%0d ex_redirects=%0d", id_redirects, ex_redirects);
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
      if (dut.dbus_req && dut.dbus_we && dut.dbus_ready &&
          dut.dbus_addr == tohost_addr && dut.dbus_wdata[0]) begin
        // tohost: code = value >> 1, 0 = PASS
        end_pass = ((dut.dbus_wdata >> 1) == 0);
        end_why  = end_pass ? "tohost" : $sformatf("tohost code %0d", dut.dbus_wdata >> 1);
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
