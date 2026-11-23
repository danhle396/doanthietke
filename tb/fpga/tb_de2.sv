// ============================================================================
// tb_de2.sv - Simulation of the DE2 board top level (fpga/board/de2_top.sv)
//   with the megafunction stand-ins of altera_stubs.sv. Run from the fpga/
//   directory so that mem/bank0.mif and mem/bank1.mif (board_demo) are found.
//   Checks: reset from KEY[0], PLL locked LED, switches -> gpio_i, LEDR <-
//   gpio_o, UART at the firmware baud rate, firmware loaded from the MIFs.
//   Sequence (one step after each '>' prompt): "s" over the UART, KEY2 pressed
//   (key_cmd types "t": self-test), KEY1 pressed ("b": benchmark), "q" over the
//   UART. PASS when the program exits with code 0, SW = 0x00a5 was reported
//   and mirrored on LEDR[7:0], the self-test printed PASS (shown as "tESt PASS",
//   LEDG7 on) and the second benchmark run printed its cycle count.
//   Display (board_display.sv): after the program, mode 00 shows the cycle
//   count of the last "cycles=" (benchmark run 2) and mode 11 the number of
//   characters sent over the UART.
// ============================================================================
`timescale 1ns/1ps

module tb_de2;

  logic        CLOCK_50 = 1'b0;
  logic [3:0]  KEY = 4'b1110;
  logic [17:0] SW = 18'h000A5;
  logic [17:0] LEDR;
  logic [8:0]  LEDG;
  logic [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
  logic        UART_TXD, UART_RXD;
  wire  [6:0]  GPIO_0;

  always #20.833 CLOCK_50 = ~CLOCK_50;   // the PLL stand-in passes the clock through

  assign GPIO_0[2] = 1'b1;               // MISO idle high (no flash module)

  de2_top dut (
    .CLOCK_50, .KEY, .SW, .LEDR, .LEDG, .HEX0, .HEX1, .HEX2, .HEX3, .HEX4, .HEX5, .HEX6,
    .HEX7, .UART_TXD, .UART_RXD, .GPIO_0
  );

  // 7-segment code -> character (digits, blank, '-', letters used by the display)
  function automatic string seg_char(input logic [6:0] s);
    case (s)
      7'b1000000: return "0";  7'b1111001: return "1";  7'b0100100: return "2";
      7'b0110000: return "3";  7'b0011001: return "4";  7'b0010010: return "5";
      7'b0000010: return "6";  7'b1111000: return "7";  7'b0000000: return "8";
      7'b0010000: return "9";  7'b1111111: return " ";  7'b0111111: return "-";
      7'b0000111: return "t";  7'b0000110: return "E";  7'b0001100: return "P";
      7'b0001000: return "A";  7'b0001110: return "F";  7'b1000111: return "L";
      default:    return "?";
    endcase
  endfunction
  function automatic string display();
    return {seg_char(HEX7), seg_char(HEX6), seg_char(HEX5), seg_char(HEX4),
            seg_char(HEX3), seg_char(HEX2), seg_char(HEX1), seg_char(HEX0)};
  endfunction

  uart_bfm u_bfm (.clk(dut.clk), .tx(UART_TXD), .rx(UART_RXD));

  string cmds[4] = '{"s\n", "KEY2", "KEY1", "q\n"};
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
      if (cmds[k] == "KEY1" || cmds[k] == "KEY2") begin
        // S and 5 have the same 7-segment shape: "tESt PASS" reads "tE5tPA55"
        if (k == 2 && (display() != "tE5tPA55" || LEDG[7] !== 1'b1)) begin
          $display("ERROR: after KEY2 (self-test) display '%s', LEDG7 %b", display(), LEDG[7]);
          errors++;
        end else if (k == 2) $display("display after KEY2: '%s'", display());
        if (cmds[k] == "KEY1") KEY[1] = 1'b0;   // press for 1 ms
        else                   KEY[2] = 1'b0;
        repeat (24000) @(posedge dut.clk);
        KEY[1] = 1'b1;
        KEY[2] = 1'b1;
      end else begin
        u_bfm.send_string(cmds[k]);
      end
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
    // exit() returns only after uart_flush(): the last frame is complete. Stay
    // below sim_ctrl's EXIT_DELAY (1000 cycles), which ends the simulation.
    repeat (300) @(posedge dut.clk);
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
    for (int i = 0; i + 21 <= all.len(); i++)
      if (all.substr(i, i + 20) == "RESULT selftest: PASS") n |= 8;
    for (int i = 0; i + 3 <= all.len(); i++) if (all.substr(i, i + 2) == "bye") n |= 4;
    if (dut.u_soc.u_sim.exit_code_q != 0) begin $display("ERROR: exit code %0d", dut.u_soc.u_sim.exit_code_q); errors++; end
    if (n != 15) begin $display("ERROR: UART output incomplete (mask %0d)", n); errors++; end
    // display: mode 00 = cycles of the last benchmark run, mode 11 = UART characters
    // mode 00 must show the number after the last "cycles=" the firmware printed
    begin
      int    p;
      string num, exp_disp;
      p = -1;
      for (int i = 0; i + 7 <= all.len(); i++) if (all.substr(i, i + 6) == "cycles=") p = i + 7;
      num = "";
      while (p >= 0 && p < all.len() && all[p] >= "0" && all[p] <= "9") begin
        num = $sformatf("%s%c", num, all[p]);
        p++;
      end
      exp_disp = $sformatf("%8s", num);
      if (num == "" || display() != exp_disp) begin
        $display("ERROR: display (mode 00) shows '%s', expected '%s'", display(), exp_disp); errors++;
      end else $display("display mode 00: '%s' (= last cycles= printed)", display());
    end
    SW[17:16] = 2'b11;
    repeat (4) @(posedge dut.clk);
    begin
      string exp_cnt;
      exp_cnt = $sformatf("%8d", all.len());
      if (display() != exp_cnt) begin
        $display("ERROR: display (mode 11) shows '%s', expected '%s'", display(), exp_cnt); errors++;
      end else $display("display mode 11: '%s'", display());
    end
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
