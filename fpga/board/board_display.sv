module board_display #(
  parameter int CLK_HZ = 24_000_000
) (
  input  logic       clk,
  input  logic       rst_n,          // PLL locked
  input  logic       soc_rst_n,      // SoC reset (asynchronous, any source)
  input  logic [1:0] mode,
  // observed SoC activity (clk domain)
  input  logic [7:0] tx_byte,
  input  logic       tx_byte_valid,
  input  logic       uart_tx,
  input  logic [31:0] fetch_adr,
  input  logic       fetch,
  input  logic [2:0] irq,            // {meip, msip, mtip}
  input  logic [3:0] spi_cs_n,
  input  logic       host_act,
  // board outputs
  output logic [6:0] hex0, hex1, hex2, hex3, hex4, hex5, hex6, hex7,  // active low
  output logic       led_tx, led_host, led_mtip, led_meip, led_spi,
  output logic       led_pass, led_fail
);

  // ------------------------------------------------------ 7-segment codes
  // active low, bit order {g,f,e,d,c,b,a}
  localparam logic [6:0] S_BLANK = 7'b1111111;
  localparam logic [6:0] S_DASH  = 7'b0111111;
  localparam logic [6:0] S_T     = 7'b0000111;
  localparam logic [6:0] S_E     = 7'b0000110;
  localparam logic [6:0] S_S     = 7'b0010010;
  localparam logic [6:0] S_P     = 7'b0001100;
  localparam logic [6:0] S_A     = 7'b0001000;
  localparam logic [6:0] S_F     = 7'b0001110;
  localparam logic [6:0] S_I     = 7'b1111001;
  localparam logic [6:0] S_L     = 7'b1000111;

  function automatic logic [6:0] seg_hex(input logic [3:0] d);
    case (d)
      4'h0: seg_hex = 7'b1000000;  4'h1: seg_hex = 7'b1111001;
      4'h2: seg_hex = 7'b0100100;  4'h3: seg_hex = 7'b0110000;
      4'h4: seg_hex = 7'b0011001;  4'h5: seg_hex = 7'b0010010;
      4'h6: seg_hex = 7'b0000010;  4'h7: seg_hex = 7'b1111000;
      4'h8: seg_hex = 7'b0000000;  4'h9: seg_hex = 7'b0010000;
      4'hA: seg_hex = 7'b0001000;  4'hB: seg_hex = 7'b0000011;
      4'hC: seg_hex = 7'b1000110;  4'hD: seg_hex = 7'b0100001;
      4'hE: seg_hex = 7'b0000110;  default: seg_hex = 7'b0001110;
    endcase
  endfunction

  // 8 BCD digits -> segments, leading zeros blanked (the last digit is kept)
  function automatic logic [55:0] seg_dec(input logic [31:0] bcd);
    logic lead;
    lead = 1'b1;
    for (int i = 7; i >= 0; i--) begin
      if (bcd[i*4 +: 4] != 4'd0 || i == 0) lead = 1'b0;
      seg_dec[i*7 +: 7] = lead ? S_BLANK : seg_hex(bcd[i*4 +: 4]);
    end
  endfunction

  // 8-digit BCD increment (saturates at 99999999)
  function automatic logic [31:0] bcd_inc(input logic [31:0] v);
    logic carry;
    carry = 1'b1;
    for (int i = 0; i < 8; i++) begin
      if (carry) begin
        if (v[i*4 +: 4] == 4'd9) v[i*4 +: 4] = 4'd0;
        else begin
          v[i*4 +: 4] = v[i*4 +: 4] + 4'd1;
          carry = 1'b0;
        end
      end
    end
    bcd_inc = carry ? 32'h9999_9999 : v;
  endfunction

  // ------------------------------------------------------ SoC reset (sync)
  logic [1:0] srst_q;
  logic       clr;                       // SoC held in reset
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) srst_q <= 2'b00;
    else        srst_q <= {srst_q[0], soc_rst_n};
  end
  assign clr = !srst_q[1];

  // ------------------------------------- what the CPU prints over the UART
  // last 7 characters, newest in [7:0]
  logic [55:0] win_q;
  logic [55:0] win_n;
  logic        cap_q, have_cyc_q, pass_q, fail_q;
  logic        show_cyc_q;               // the cycle count came after the result
  logic [31:0] cyc_q;                    // BCD digits after "cycles="
  logic [31:0] uart_cnt_q;               // BCD character count
  logic        is_digit;

  assign win_n    = {win_q[47:0], tx_byte};
  assign is_digit = (tx_byte >= "0") && (tx_byte <= "9");

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      win_q      <= '0;
      cap_q      <= 1'b0;
      have_cyc_q <= 1'b0;
      show_cyc_q <= 1'b0;
      pass_q     <= 1'b0;
      fail_q     <= 1'b0;
      cyc_q      <= '0;
      uart_cnt_q <= '0;
    end else if (clr) begin
      win_q      <= '0;
      cap_q      <= 1'b0;
      have_cyc_q <= 1'b0;
      show_cyc_q <= 1'b0;
      pass_q     <= 1'b0;
      fail_q     <= 1'b0;
      cyc_q      <= '0;
      uart_cnt_q <= '0;
    end else if (tx_byte_valid) begin
      win_q      <= win_n;
      uart_cnt_q <= bcd_inc(uart_cnt_q);
      if (cap_q) begin
        if (is_digit) cyc_q <= {cyc_q[27:0], tx_byte[3:0]};
        else begin
          cap_q      <= 1'b0;
          have_cyc_q <= 1'b1;
          show_cyc_q <= 1'b1;
        end
      end
      if (win_n == "cycles=") begin
        cap_q <= 1'b1;
        cyc_q <= '0;
      end
      if (win_n[47:0] == ": PASS") begin pass_q <= 1'b1; fail_q <= 1'b0; show_cyc_q <= 1'b0; end
      if (win_n[47:0] == ": FAIL") begin fail_q <= 1'b1; pass_q <= 1'b0; show_cyc_q <= 1'b0; end
    end
  end

  // ----------------------------------------------- PC sampled at 8 Hz
  localparam int TICK8 = CLK_HZ / 8;
  localparam int SEC   = CLK_HZ;
  logic [24:0] t8_q, t1_q;
  logic [31:0] pc_last_q, pc_show_q;
  logic [31:0] fps_cnt_q, fps_show_q;    // BCD fetches per second

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      t8_q       <= '0;
      t1_q       <= '0;
      pc_last_q  <= '0;
      pc_show_q  <= '0;
      fps_cnt_q  <= '0;
      fps_show_q <= '0;
    end else begin
      if (fetch) pc_last_q <= fetch_adr;
      if (t8_q == TICK8[24:0] - 25'd1) begin
        t8_q      <= '0;
        pc_show_q <= pc_last_q;
      end else begin
        t8_q <= t8_q + 25'd1;
      end
      if (t1_q == SEC[24:0] - 25'd1) begin
        t1_q       <= '0;
        fps_show_q <= fps_cnt_q;
        fps_cnt_q  <= fetch ? 32'h0000_0001 : 32'h0;
      end else begin
        t1_q <= t1_q + 25'd1;
        if (fetch) fps_cnt_q <= bcd_inc(fps_cnt_q);
      end
      if (clr) begin
        pc_last_q  <= '0;
        fps_cnt_q  <= '0;
        fps_show_q <= '0;
      end
    end
  end

  // ------------------------------------------------------------ digits
  logic [55:0] digits;                   // {hex7, ..., hex0}
  always_comb begin
    case (mode)
      2'd0: begin
        if (have_cyc_q && show_cyc_q) digits = seg_dec(cyc_q);
        else if (fail_q)              digits = {S_T, S_E, S_S, S_T, S_F, S_A, S_I, S_L};
        else if (pass_q)              digits = {S_T, S_E, S_S, S_T, S_P, S_A, S_S, S_S};
        else                          digits = {8{S_DASH}};
      end
      2'd1: for (int i = 0; i < 8; i++) digits[i*7 +: 7] = seg_hex(pc_show_q[i*4 +: 4]);
      2'd2: digits = seg_dec(fps_show_q);
      default: digits = seg_dec(uart_cnt_q);
    endcase
  end

  assign {hex7, hex6, hex5, hex4, hex3, hex2, hex1, hex0} = digits;

  // ------------------------------------------------- stretched event LEDs
  localparam int STRETCH = 21;           // 2^21 clocks = 87 ms at 24 MHz
  logic [2:0] irq_q;
  logic [STRETCH-1:0] s_tx, s_host, s_mtip, s_meip, s_spi;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_q  <= '0;
      s_tx   <= '0;
      s_host <= '0;
      s_mtip <= '0;
      s_meip <= '0;
      s_spi  <= '0;
    end else begin
      irq_q <= irq;
      s_tx   <= !uart_tx              ? '1 : (s_tx   != 0 ? s_tx   - 1'b1 : '0);
      s_host <= host_act              ? '1 : (s_host != 0 ? s_host - 1'b1 : '0);
      s_mtip <= (irq[0] && !irq_q[0]) ? '1 : (s_mtip != 0 ? s_mtip - 1'b1 : '0);
      s_meip <= (irq[2] && !irq_q[2]) ? '1 : (s_meip != 0 ? s_meip - 1'b1 : '0);
      s_spi  <= (spi_cs_n != 4'hF)    ? '1 : (s_spi  != 0 ? s_spi  - 1'b1 : '0);
    end
  end

  assign led_tx   = (s_tx   != 0);
  assign led_host = (s_host != 0);
  assign led_mtip = (s_mtip != 0);
  assign led_meip = (s_meip != 0);
  assign led_spi  = (s_spi  != 0);
  assign led_pass = pass_q;
  assign led_fail = fail_q;

endmodule
