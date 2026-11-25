module key_cmd #(
  parameter int BIT_CYCLES = 208       // 16 x (BAUD_DIV + 1), BAUD_DIV = 12
) (
  input  logic       clk,
  input  logic       rst_n,
  input  logic [3:1] key_n,            // KEY[3:1], active low
  output logic       tx                // to the SoC uart_rx, idle 1
);

  localparam int BIT_M1_I = BIT_CYCLES - 1;
  localparam logic [15:0] BIT_M1 = BIT_M1_I[15:0];

  logic [3:1] k0_q, k1_q, k2_q;        // two-flop sync + previous value
  logic [3:1] press;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k0_q <= '1;
      k1_q <= '1;
      k2_q <= '1;
    end else begin
      k0_q <= key_n;
      k1_q <= k0_q;
      k2_q <= k1_q;
    end
  end
  assign press = k2_q & ~k1_q;         // 1 -> 0

  // two characters: the command letter, then '\n'
  logic        second_q;               // sending '\n'
  logic [9:0]  sh_q;
  logic [3:0]  bits_q;
  logic [15:0] cnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      second_q <= 1'b0;
      sh_q     <= '1;
      bits_q   <= '0;
      cnt_q    <= '0;
    end else if (bits_q == 0) begin
      sh_q <= '1;
      if (second_q) begin
        sh_q     <= {1'b1, 8'h0A, 1'b0};
        bits_q   <= 4'd10;
        cnt_q    <= BIT_M1;
        second_q <= 1'b0;
      end else if (press != 3'b000) begin
        sh_q     <= {1'b1, (press[1] ? "b" : press[2] ? "t" : "f"), 1'b0};
        bits_q   <= 4'd10;
        cnt_q    <= BIT_M1;
        second_q <= 1'b1;
      end
    end else if (cnt_q != 0) begin
      cnt_q <= cnt_q - 16'd1;
    end else begin
      sh_q   <= {1'b1, sh_q[9:1]};
      bits_q <= bits_q - 4'd1;
      cnt_q  <= BIT_M1;
    end
  end

  assign tx = sh_q[0];

endmodule
