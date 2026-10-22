// uart_bfm.sv - UART bus functional model.
//   Receiver: decodes the DUT's TX line (8N1/8E1/8O1, 1-2 stop bits), stores
//   bytes in rx_q, counts frame/parity errors, optionally logs them to a file
//   and echoes complete lines to stdout ("[uart] ...").
//   Sender: send_byte() drives the DUT's RX line, with optional parity or
//   stop-bit errors; send_file() sends the bytes of a file.
//   check_expected(file) compares everything received with a text file.
//   Configure bit_cycles (= 16 x (BAUD_DIV + 1)), parity_en, parity_odd, stop2.
`timescale 1ns/1ps

module uart_bfm (
  input  logic clk,
  input  logic tx,      // DUT -> BFM
  output logic rx       // BFM -> DUT
);

  int   bit_cycles = 16;
  bit   parity_en  = 0;
  bit   parity_odd = 0;
  bit   stop2      = 0;
  bit   echo       = 1;
  byte  rx_q[$];
  int   rx_count = 0;
  int   frame_errors = 0;
  int   parity_errors = 0;
  integer log_fd = 0;
  byte    trigger = ">";    // prompt character counted in trigger_count
  int     trigger_count = 0;
  string  line_buf = "";

  initial rx = 1'b1;

  task automatic open_log(input string fname);
    log_fd = $fopen(fname, "w");
  endtask

  // ---------------- receiver ----------------
  initial begin
    logic [7:0] b;
    logic       p;
    forever begin
      @(negedge tx);
      repeat (bit_cycles / 2) @(posedge clk);
      if (tx !== 1'b0) continue;  // glitch
      for (int i = 0; i < 8; i++) begin
        repeat (bit_cycles) @(posedge clk);
        b[i] = tx;
      end
      if (parity_en) begin
        repeat (bit_cycles) @(posedge clk);
        p = tx;
        if (((^b) ^ p) != parity_odd) parity_errors++;
      end
      repeat (bit_cycles) @(posedge clk);
      if (tx !== 1'b1) frame_errors++;
      rx_q.push_back(b);
      rx_count++;
      if (b == trigger) trigger_count++;
      if (log_fd != 0) begin
        $fwrite(log_fd, "%c", b);
        $fflush(log_fd);
      end
      if (echo) begin
        if (b == 8'h0A) begin
          $display("[uart] %s", line_buf);
          line_buf = "";
        end else if (b != 8'h0D) begin
          line_buf = {line_buf, string'(b)};
        end
      end
      // stay inside the stop bit so the next falling edge is a real start
    end
  end

  // ---------------- sender ----------------
  task automatic send_byte(input logic [7:0] b, input bit bad_parity = 0,
                           input bit bad_stop = 0);
    rx = 1'b0;
    repeat (bit_cycles) @(posedge clk);
    for (int i = 0; i < 8; i++) begin
      rx = b[i];
      repeat (bit_cycles) @(posedge clk);
    end
    if (parity_en) begin
      rx = (^b) ^ parity_odd ^ bad_parity;
      repeat (bit_cycles) @(posedge clk);
    end
    rx = bad_stop ? 1'b0 : 1'b1;
    repeat (bit_cycles) @(posedge clk);
    rx = 1'b1;
    if (stop2 || bad_stop) repeat (bit_cycles) @(posedge clk);
  endtask

  task automatic send_string(input string s, input int gap_cycles = 0);
    for (int i = 0; i < s.len(); i++) begin
      send_byte(s[i]);
      repeat (gap_cycles) @(posedge clk);
    end
  endtask

  task automatic send_file(input string fname, input int gap_cycles = 0);
    integer fd;
    int c;
    fd = $fopen(fname, "r");
    if (fd == 0) begin
      $display("uart_bfm: cannot open %s", fname);
      return;
    end
    c = $fgetc(fd);
    while (c != -1) begin
      send_byte(8'(c));
      repeat (gap_cycles) @(posedge clk);
      c = $fgetc(fd);
    end
    $fclose(fd);
  endtask

  // Glob match of one line: '*' matches any (possibly empty) substring.
  function automatic bit glob_match(input string pat, input string s);
    int pi, si, star_p, star_s;
    pi = 0; si = 0; star_p = -1; star_s = 0;
    while (si < s.len()) begin
      if (pi < pat.len() && pat[pi] != "*" && pat[pi] == s[si]) begin
        pi++; si++;
      end else if (pi < pat.len() && pat[pi] == "*") begin
        star_p = pi; star_s = si; pi++;
      end else if (star_p >= 0) begin
        pi = star_p + 1; star_s++; si = star_s;
      end else return 0;
    end
    while (pi < pat.len() && pat[pi] == "*") pi++;
    return pi == pat.len();
  endfunction

  // Line-by-line comparison with an expected text file whose lines may use
  // '*' wildcards (for numbers that depend on timing, e.g. cycle counts).
  // Returns the number of mismatching lines (+1 if the line counts differ).
  function automatic int check_expected_glob(input string fname);
    string exp_lines[$], got_lines[$], cur;
    integer fd;
    int c, bad;
    fd = $fopen(fname, "r");
    if (fd == 0) begin
      $display("uart_bfm: cannot open expected file %s", fname);
      return 1;
    end
    cur = "";
    c = $fgetc(fd);
    while (c != -1) begin
      if (c == 10) begin exp_lines.push_back(cur); cur = ""; end
      else if (c != 13) cur = {cur, string'(byte'(c))};
      c = $fgetc(fd);
    end
    if (cur.len() != 0) exp_lines.push_back(cur);
    $fclose(fd);
    cur = "";
    foreach (rx_q[i]) begin
      if (rx_q[i] == 8'h0A) begin got_lines.push_back(cur); cur = ""; end
      else if (rx_q[i] != 8'h0D) cur = {cur, string'(rx_q[i])};
    end
    if (cur.len() != 0) got_lines.push_back(cur);
    bad = 0;
    foreach (exp_lines[i]) begin
      if (i >= got_lines.size()) begin
        $display("uart_bfm: missing line %0d: '%s'", i + 1, exp_lines[i]);
        return bad + 1;
      end
      if (!glob_match(exp_lines[i], got_lines[i])) begin
        if (bad < 10) $display("uart_bfm: line %0d got '%s' expected '%s'", i + 1, got_lines[i], exp_lines[i]);
        bad++;
      end
    end
    if (got_lines.size() > exp_lines.size()) begin
      $display("uart_bfm: %0d extra lines, first: '%s'", got_lines.size() - exp_lines.size(),
               got_lines[exp_lines.size()]);
      bad++;
    end
    return bad;
  endfunction

  // Compare received bytes with a file. Returns the number of mismatches
  // (a length difference counts as one mismatch).
  function automatic int check_expected(input string fname);
    integer fd;
    int c, i, bad;
    fd = $fopen(fname, "r");
    if (fd == 0) begin
      $display("uart_bfm: cannot open expected file %s", fname);
      return 1;
    end
    i = 0; bad = 0;
    c = $fgetc(fd);
    while (c != -1) begin
      if (i >= rx_q.size()) begin
        $display("uart_bfm: missing output from byte %0d", i);
        bad++;
        break;
      end
      if (rx_q[i] != 8'(c)) begin
        if (bad < 5) $display("uart_bfm: byte %0d got %02x exp %02x", i, rx_q[i], c);
        bad++;
      end
      i++;
      c = $fgetc(fd);
    end
    if (bad == 0 && i != rx_q.size()) begin
      $display("uart_bfm: %0d extra bytes received", rx_q.size() - i);
      bad++;
    end
    $fclose(fd);
    return bad;
  endfunction

endmodule
