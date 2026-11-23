// ============================================================================
// tb_jtag_bridge.sv - Unit test of fpga/board/jtag_uart_bridge.sv: a model of
//   the host (the same DR protocol as fpga/tools/jtag_uart.tcl) on an
//   asynchronous TCK, a SoC-side UART transmitter and a receiver on uart_rx.
//   1. SoC sends 300 bytes back-to-back while the host polls: every byte
//      arrives once, in order.
//   2. Host sends 40 bytes: they appear on uart_rx as 8N1 frames, in order.
//   3. Both directions at the same time.
//   4. Host reset bit -> cpu_rst_req.
//   5. FIFO overflow (small FIFO): the first 2^FIFO_AW + 1 bytes are kept
//      (FIFO + the byte waiting for the host), the sticky flag is set.
//   6. Host reset empties the FIFO and clears the overflow flag.
// ============================================================================
`timescale 1ns/1ps

module tb_jtag_bridge;

  localparam int BIT = 208;
  localparam int AW  = 6;          // 64-byte FIFO so overflow is quick to reach

  logic clk = 1'b0, rst_n = 1'b0;
  logic tck = 1'b0, tdi = 1'b0, sel = 1'b0, cdr = 1'b0, sdr = 1'b0, udr = 1'b0;
  logic tdo, uart_tx = 1'b1, uart_rx, cpu_rst_req;
  logic [7:0] tx_byte;
  logic tx_byte_valid, host_act;

  always #20.833 clk = ~clk;       // 24 MHz
  always #53.7   tck = ~tck;       // ~9.3 MHz, unrelated to clk

  jtag_uart_bridge #(.BIT_CYCLES(BIT), .FIFO_AW(AW)) dut (.*);

  int errors = 0;

  // ------------------------------------------------------------ host model
  logic       h_seq = 1'b0, h_rst = 1'b0;
  logic [7:0] h_data = 8'h00;
  byte        h_txq[$];            // bytes to send to the SoC
  byte        h_rx[$];             // bytes received from the SoC
  logic       last_ovf;
  logic       h_ack = 1'b0;         // last captured in_ack

  task automatic scan(input logic [23:0] din, output logic [23:0] dout);
    @(negedge tck); sel = 1'b1; cdr = 1'b1;
    @(negedge tck); cdr = 1'b0; sdr = 1'b1;
    for (int i = 0; i < 24; i++) begin
      dout[i] = tdo;               // host samples TDO before the shifting edge
      tdi = din[i];
      @(negedge tck);
    end
    sdr = 1'b0;                    // Exit1-DR
    @(negedge tck); udr = 1'b1;
    @(negedge tck); udr = 1'b0; sel = 1'b0;
    repeat (2) @(negedge tck);     // Run-Test/Idle
  endtask

  task automatic host_poll();
    logic [23:0] d;
    scan({14'b0, h_rst, h_seq, h_data}, d);
    if (d[23:16] != 8'hA5) begin
      $display("ERROR: magic %02h", d[23:16]); errors++;
    end
    if (d[12] != h_rst) ;          // echo lags by the synchronizer: not checked here
    last_ovf = d[11];
    h_ack    = d[10];
    if (d[8] != d[9]) h_rx.push_back(d[7:0]);
    if (d[10] == h_seq && h_txq.size() > 0) begin
      h_data = h_txq.pop_front();
      h_seq  = ~h_seq;
    end
  endtask

  // ----------------------------------------------------- SoC-side UART
  task automatic soc_send(input byte b);
    logic [9:0] f;
    f = {1'b1, b, 1'b0};
    for (int i = 0; i < 10; i++) begin
      uart_tx = f[i];
      repeat (BIT) @(posedge clk);
    end
  endtask

  byte soc_rx[$];                  // bytes decoded from uart_rx
  initial begin
    forever begin
      byte b;
      @(negedge uart_rx);
      repeat (BIT / 2) @(posedge clk);
      if (uart_rx !== 1'b0) continue;
      for (int i = 0; i < 8; i++) begin
        repeat (BIT) @(posedge clk);
        b[i] = uart_rx;
      end
      repeat (BIT) @(posedge clk);
      if (uart_rx !== 1'b1) begin $display("ERROR: uart_rx stop bit"); errors++; end
      soc_rx.push_back(b);
    end
  end

  // ------------------------------------------------------------- checks
  task automatic expect_eq(input string what, input byte got[$], input byte exp[$]);
    if (got.size() != exp.size()) begin
      $display("ERROR: %s: %0d bytes, expected %0d", what, got.size(), exp.size()); errors++;
      return;
    end
    foreach (exp[i]) if (got[i] != exp[i]) begin
      $display("ERROR: %s: byte %0d = %02h, expected %02h", what, i, got[i], exp[i]); errors++;
      return;
    end
    $display("  %s: %0d bytes OK", what, exp.size());
  endtask

  byte exp_up[$], exp_down[$];
  bit  soc_done;

  initial begin
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    // 1. SoC -> host, 300 bytes back-to-back while the host polls
    exp_up = {};
    for (int i = 0; i < 300; i++) exp_up.push_back(byte'((i * 37 + 11) & 8'hFF));
    soc_done = 0;
    fork
      begin foreach (exp_up[i]) soc_send(exp_up[i]); soc_done = 1; end
      begin
        while (!soc_done || h_rx.size() < exp_up.size()) begin
          host_poll();
          if (h_rx.size() > exp_up.size()) break;
        end
      end
    join
    repeat (20) host_poll();       // nothing more may arrive
    expect_eq("SoC -> host", h_rx, exp_up);

    // 2. host -> SoC, 40 bytes
    h_rx = {}; soc_rx = {}; exp_down = {};
    for (int i = 0; i < 40; i++) exp_down.push_back(byte'(8'h20 + i));
    h_txq = exp_down;
    while (h_txq.size() > 0 || h_ack != h_seq) host_poll();
    repeat (BIT * 12) @(posedge clk);
    expect_eq("host -> SoC", soc_rx, exp_down);

    // 3. both directions together
    h_rx = {}; soc_rx = {};
    h_txq = exp_down;
    soc_done = 0;
    fork
      begin for (int i = 0; i < 60; i++) soc_send(exp_up[i]); soc_done = 1; end
      begin while (!soc_done || h_rx.size() < 60 || h_txq.size() > 0 || h_ack != h_seq) host_poll(); end
    join
    repeat (BIT * 12) @(posedge clk);
    expect_eq("both: SoC -> host", h_rx, exp_up[0:59]);
    expect_eq("both: host -> SoC", soc_rx, exp_down);

    // 4. host reset bit
    h_rst = 1'b1; host_poll();
    repeat (4) @(posedge clk);
    if (cpu_rst_req !== 1'b1) begin $display("ERROR: cpu_rst_req not set"); errors++; end
    h_rst = 1'b0; host_poll();
    repeat (4) @(posedge clk);
    if (cpu_rst_req !== 1'b0) begin $display("ERROR: cpu_rst_req not cleared"); errors++; end
    else $display("  host reset: OK");

    // 5. overflow: 2^AW + 6 bytes with no host polling
    h_rx = {};
    for (int i = 0; i < (1 << AW) + 6; i++) soc_send(byte'(i));
    for (int i = 0; i < (1 << AW) + 10; i++) host_poll();
    if (h_rx.size() != (1 << AW) + 1) begin
      $display("ERROR: overflow: kept %0d bytes, expected %0d", h_rx.size(), (1 << AW) + 1); errors++;
    end else begin
      foreach (h_rx[i]) if (h_rx[i] != byte'(i)) begin
        $display("ERROR: overflow: byte %0d = %02h", i, h_rx[i]); errors++; break;
      end
    end
    if (!last_ovf) begin $display("ERROR: overflow flag not set"); errors++; end
    else $display("  overflow: OK (%0d bytes kept, flag set)", h_rx.size());

    // 6. host reset clears the FIFO and the flag
    for (int i = 0; i < 20; i++) soc_send(byte'(i));
    h_rx = {};
    h_rst = 1'b1; host_poll();
    repeat (8) @(posedge clk);
    h_rst = 1'b0;
    repeat (4) host_poll();
    // at most 2 bytes: the one read by the scan that sends the reset (capture
    // comes before update) and the one already in the holding register
    if (h_rx.size() > 2 || last_ovf) begin
      $display("ERROR: host reset: %0d bytes left, overflow flag %0d", h_rx.size(), last_ovf); errors++;
    end else $display("  host reset clears FIFO and flag: OK");
    h_rx = {};
    soc_send(8'h5A);
    repeat (4) host_poll();
    if (h_rx.size() != 1 || h_rx[0] != 8'h5A) begin
      $display("ERROR: after host reset: got %0d bytes", h_rx.size()); errors++;
    end

    if (errors == 0) $display("PASS");
    else             $display("FAIL: %0d errors", errors);
    $finish;
  end

  initial begin
    #2s;
    $display("FAIL: timeout");
    $finish;
  end

endmodule
