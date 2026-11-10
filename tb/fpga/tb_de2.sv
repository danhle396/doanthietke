// ============================================================================
// tb_de2.sv - Simulation of the DE2 board top level (fpga/board/de2_top.sv)
//   with the megafunction stand-ins of altera_stubs.sv. Run from the fpga/
//   directory so that mem/bank0.mif and mem/bank1.mif (board_demo) are found.
//   Checks: reset from KEY[0], PLL locked LED, switches -> gpio_i, LEDR <-
//   gpio_o, UART at the firmware baud rate, firmware loaded from the MIFs.
//   Sequence: commands "s", "b", "q" (one after each '>' prompt); PASS when
//   the program exits with code 0, SW = 0x00a5 was reported and mirrored on
//   LEDR[7:0], and the second benchmark run printed its cycle count.
// ============================================================================
`timescale 1ns/1ps

module tb_de2;

  logic        CLOCK_50 = 1'b0;
  logic [3:0]  KEY = 4'b1110;
  logic [17:0] SW = 18'h000A5;
  logic [17:0] LEDR;
  logic [8:0]  LEDG;
  logic        UART_TXD, UART_RXD;
  wire  [6:0]  GPIO_0;

  always #20.833 CLOCK_50 = ~CLOCK_50;   // the PLL stand-in passes the clock through

  assign GPIO_0[2] = 1'b1;               // MISO idle high (no flash module)

  de2_top dut (
    .CLOCK_50, .KEY, .SW, .LEDR, .LEDG, .UART_TXD, .UART_RXD, .GPIO_0
  );

  uart_bfm u_bfm (.clk(dut.clk), .tx(UART_TXD), .rx(UART_RXD));

  string cmds[3] = '{"s\n", "b\n", "q\n"};
  string log_name = "tb_de2_uart.txt";
  int    errors = 0;

  always @(posedge dut.clk) u_bfm.bit_cycles = 16 * (int'(dut.u_soc.u_uart.baud_q) + 1);

  initial begin
    if ($value$plusargs("uart_log=%s", log_name)) ;
    u_bfm.open_log(log_name);
    repeat (20) @(posedge CLOCK_50);
    if (LEDG[0] !== 1'b1) begin $display("ERROR: PLL locked LED off"); errors++; end
    KEY[0] = 1'b1;
    foreach (cmds[k]) begin
      wait (u_bfm.trigger_count >= k + 1);
      repeat (u_bfm.bit_cycles * 2) @(posedge dut.clk);
      u_bfm.send_string(cmds[k]);
      if (k == 0) begin
        repeat (u_bfm.bit_cycles * 60) @(posedge dut.clk);
        if (LEDR[7:0] !== 8'hA5) begin
          $display("ERROR: LEDR[7:0] = %02h, expected a5 (SW mirror)", LEDR[7:0]); errors++;
        end
      end
    end
  end

  initial begin
    int fd, n;
    string line, all;
    wait (dut.u_soc.u_sim.exit_req_q);
    repeat (u_bfm.bit_cycles * 12) @(posedge dut.clk);
    $fflush();
    all = "";
    fd = $fopen(log_name, "r");
    while (fd != 0 && !$feof(fd)) begin
      void'($fgets(line, fd));
      all = {all, line};
    end
    if (fd != 0) $fclose(fd);
    n = 0;
    for (int i = 0; i + 17 <= all.len(); i++) begin
      if (all.substr(i, i + 16) == "SW[15:0] = 0x00a5") n |= 1;
      if (all.substr(i, i + 5) == "run 2:")             n |= 2;
    end
    for (int i = 0; i + 3 <= all.len(); i++) if (all.substr(i, i + 2) == "bye") n |= 4;
    if (dut.u_soc.u_sim.exit_code_q != 0) begin $display("ERROR: exit code %0d", dut.u_soc.u_sim.exit_code_q); errors++; end
    if (n != 7) begin $display("ERROR: UART output incomplete (mask %0d)", n); errors++; end
    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end

  initial begin
    #200ms;
    $display("FAIL: timeout");
    $finish;
  end

endmodule
