  // ---------------- UART ----------------
  uart_bfm u_uart_bfm (.clk, .tx(uart_tx), .rx(uart_rx));

  always @(posedge clk) begin
    u_uart_bfm.bit_cycles = 16 * (int'(dut.u_uart.baud_q) + 1);
    u_uart_bfm.parity_en  = dut.u_uart.ctrl_q[2];
    u_uart_bfm.parity_odd = dut.u_uart.ctrl_q[3];
    u_uart_bfm.stop2      = dut.u_uart.ctrl_q[4];
  end

  initial begin
    string fname, mode, log_name;
    string lines[$], cur;
    integer fd;
    int c, gap;
    if ($value$plusargs("uart_log=%s", log_name)) u_uart_bfm.open_log(log_name);
    if (!$value$plusargs("uart_rx_mode=%s", mode)) mode = "line";
    if (!$value$plusargs("uart_rx_gap=%d", gap)) gap = 0;
    if ($value$plusargs("uart_rx_file=%s", fname)) begin
      fd = $fopen(fname, "r");
      if (fd == 0) $fatal(1, "cannot open %s", fname);
      cur = "";
      c = $fgetc(fd);
      while (c != -1) begin
        cur = {cur, string'(byte'(c))};
        if (c == 10 || mode == "all") begin
          if (c == 10 || mode != "all") begin lines.push_back(cur); cur = ""; end
        end
        c = $fgetc(fd);
      end
      if (cur.len() != 0) lines.push_back(cur);
      $fclose(fd);
      foreach (lines[k]) begin
        wait (u_uart_bfm.trigger_count >= k + 1);
        repeat (u_uart_bfm.bit_cycles * 2) @(posedge clk);
        for (int i = 0; i < lines[k].len(); i++) begin
          u_uart_bfm.send_byte(lines[k][i]);
          repeat (gap) @(posedge clk);
        end
      end
    end
  end

  // ---------------- SPI ----------------
  logic miso_flash, miso_slave;

  spi_flash_bfm u_flash (.sclk(spi_sclk), .mosi(spi_mosi), .cs_n(spi_cs_n[0]), .miso(miso_flash));
  spi_slave_bfm u_spi_slave (.sclk(spi_sclk), .mosi(spi_mosi), .cs_n(spi_cs_n[1]), .miso(miso_slave));

  assign spi_miso = !spi_cs_n[0] ? miso_flash : (!spi_cs_n[1] ? miso_slave : 1'b0);

  initial u_spi_slave.echo_mode = 1;
  always @(posedge clk) begin
    u_spi_slave.cpol      = dut.u_spi.ctrl_q[1];
    u_spi_slave.cpha      = dut.u_spi.ctrl_q[2];
    u_spi_slave.lsb_first = dut.u_spi.ctrl_q[3];
  end

  // ---------------- GPIO ----------------
  localparam int STIM_GAP = 300;
  logic [3:0] gpio_stim = 4'b1010;
  logic       req_d = 1'b0;

  assign gpio_i = {gpio_o[7:0], 4'b0000, gpio_stim};

  always @(posedge clk) begin
    req_d <= gpio_o[15];
    if (gpio_o[15] && !req_d) begin
      fork begin
        for (int r = 0; r < 4; r++) begin
          repeat (STIM_GAP) @(posedge clk);
          gpio_stim = ~gpio_stim;
        end
      end join_none
    end
  end

  // ---------------- end-of-test checks ----------------
  task automatic bfm_final_check(inout bit pass, inout string why);
    string exp_file;
    int bad;
    if (u_uart_bfm.line_buf.len() != 0) $display("[uart] %s", u_uart_bfm.line_buf);
    $display("[bfm] uart_rx_bytes=%0d uart_frame_err=%0d uart_parity_err=%0d spi_slave_bytes=%0d flash_errors=%0d flash_ignored=%0d",
             u_uart_bfm.rx_count, u_uart_bfm.frame_errors, u_uart_bfm.parity_errors,
             u_spi_slave.rx_q.size(), u_flash.errors, u_flash.ignored);
    if ($value$plusargs("uart_expect=%s", exp_file)) begin
      bad = u_uart_bfm.check_expected_glob(exp_file);
      if (bad != 0 && pass) begin
        pass = 0;
        why = $sformatf("UART output differs from %s (%0d lines)", exp_file, bad);
      end
    end
    if ((u_uart_bfm.frame_errors != 0 || u_uart_bfm.parity_errors != 0) && pass) begin
      pass = 0;
      why = "UART frame/parity error seen by the BFM";
    end
    if (u_flash.errors != 0 && pass) begin
      pass = 0;
      why = "SPI flash protocol misuse";
    end
  endtask
