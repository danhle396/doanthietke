module jtag_uart_bridge #(
  parameter int BIT_CYCLES = 208,      // 16 x (BAUD_DIV + 1), BAUD_DIV = 12
  parameter int FIFO_AW    = 13        // 8 KB FIFO (M4K)
) (
  input  logic clk,
  input  logic rst_n,                  // PLL locked (not the SoC reset)
  // virtual JTAG (tck domain)
  input  logic tck,
  input  logic tdi,
  output logic tdo,
  input  logic sel,                    // virtual IR == 1
  input  logic cdr,                    // Capture-DR
  input  logic sdr,                    // Shift-DR
  input  logic udr,                    // Update-DR
  // SoC side (clk domain)
  input  logic uart_tx,                // SoC transmit line (tapped)
  output logic uart_rx,                // to the SoC receive line, idle 1
  output logic cpu_rst_req,            // 1 = host holds the SoC in reset
  // for the board display (clk domain)
  output logic [7:0] tx_byte,          // byte decoded from uart_tx ...
  output logic       tx_byte_valid,    // ... valid for one clock
  output logic       host_act          // one clock per DR scan of the host
);

  localparam int W = 24;
  localparam int HALF_M2_I = BIT_CYCLES / 2 - 2;     // start edge -> middle of start bit
  localparam int BIT_M1_I  = BIT_CYCLES - 1;
  localparam logic [15:0] HALF_M2 = HALF_M2_I[15:0];
  localparam logic [15:0] BIT_M1  = BIT_M1_I[15:0];

  // ---------------------------------------------------------------- tck domain
  logic [W-1:0] sr_t;
  logic         just_cap_t, cap_seq_t;
  logic [7:0]   in_data_t;
  logic         in_seq_t, rst_req_t;
  logic         act_t;                 // toggles at every Update-DR

  // clk-domain values sampled at Capture-DR
  logic [7:0]   out_data_c;
  logic         out_seq_c, in_ack_c, ovf_c, rst_req_c;

  always_ff @(posedge tck) begin
    just_cap_t <= 1'b0;
    if (sel && cdr) begin
      sr_t       <= {8'hA5, 3'b000, rst_req_c, ovf_c, in_ack_c, cap_seq_t, out_seq_c, out_data_c};
      just_cap_t <= 1'b1;
    end else if (sel && sdr) begin
      sr_t <= {tdi, sr_t[W-1:1]};
    end
    // the captured out_seq (one flip-flop, so host and board agree on it)
    if (just_cap_t) cap_seq_t <= sr_t[8];
    if (sel && udr) begin
      act_t     <= ~act_t;
      in_data_t <= sr_t[7:0];
      in_seq_t  <= sr_t[8];
      rst_req_t <= sr_t[9];
    end
  end

  assign tdo = sr_t[0];

  // ---------------------------------------------------------- tck -> clk sync
  logic [1:0] ack_s, inseq_s, rst_s;
  logic [2:0] act_s;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ack_s   <= 2'b00;
      inseq_s <= 2'b00;
      rst_s   <= 2'b00;
      act_s   <= 3'b000;
    end else begin
      ack_s   <= {ack_s[0], cap_seq_t};
      inseq_s <= {inseq_s[0], in_seq_t};
      rst_s   <= {rst_s[0], rst_req_t};
      act_s   <= {act_s[1:0], act_t};
    end
  end
  assign host_act = act_s[2] ^ act_s[1];
  assign cpu_rst_req = rst_s[1];
  assign rst_req_c   = rst_s[1];

  // --------------------------------------------- SoC uart_tx -> byte (8N1)
  typedef enum logic [1:0] {R_IDLE, R_START, R_DATA, R_STOP} rx_state_e;
  rx_state_e   rs_q;
  logic        tx_q;
  logic [15:0] rcnt_q;
  logic [2:0]  rbit_q;
  logic [7:0]  rbyte_q;
  logic        push;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rs_q    <= R_IDLE;
      tx_q    <= 1'b1;
      rcnt_q  <= '0;
      rbit_q  <= '0;
      rbyte_q <= '0;
      push    <= 1'b0;
    end else begin
      tx_q <= uart_tx;
      push <= 1'b0;
      if (rcnt_q != 0) rcnt_q <= rcnt_q - 16'd1;
      case (rs_q)
        R_IDLE: if (!tx_q) begin                       // start bit edge
          rcnt_q <= HALF_M2;
          rs_q   <= R_START;
        end
        R_START: if (rcnt_q == 0) begin                // middle of the start bit
          if (!tx_q) begin
            rcnt_q <= BIT_M1;
            rbit_q <= '0;
            rs_q   <= R_DATA;
          end else begin
            rs_q <= R_IDLE;                            // glitch
          end
        end
        R_DATA: if (rcnt_q == 0) begin
          rbyte_q <= {tx_q, rbyte_q[7:1]};
          rcnt_q  <= BIT_M1;
          rbit_q  <= rbit_q + 3'd1;
          if (rbit_q == 3'd7) rs_q <= R_STOP;
        end
        R_STOP: if (rcnt_q == 0) begin                 // middle of the stop bit
          push <= tx_q;                                // framing error: drop
          if (tx_q) rs_q <= R_IDLE;                    // else wait for idle
        end
        default: rs_q <= R_IDLE;
      endcase
    end
  end

  assign tx_byte       = rbyte_q;
  assign tx_byte_valid = push;

  // -------------------------------------------------------------- 8 KB FIFO
  localparam int DEPTH = 1 << FIFO_AW;
  logic [7:0]       mem [0:DEPTH-1];
  logic [FIFO_AW:0] wp_q, rp_q;
  logic [7:0]       rd_q;
  logic             full, empty;

  assign full  = (wp_q[FIFO_AW] != rp_q[FIFO_AW]) && (wp_q[FIFO_AW-1:0] == rp_q[FIFO_AW-1:0]);
  assign empty = (wp_q == rp_q);

  always_ff @(posedge clk) begin
    if (push && !full) mem[wp_q[FIFO_AW-1:0]] <= rbyte_q;
    rd_q <= mem[rp_q[FIFO_AW-1:0]];
  end

  // -------------------------------------- FIFO -> out_data / out_seq handshake
  typedef enum logic [1:0] {O_IDLE, O_W1, O_LOAD, O_TOG} out_state_e;
  out_state_e os_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wp_q       <= '0;
      rp_q       <= '0;
      ovf_c      <= 1'b0;
      os_q       <= O_IDLE;
      out_data_c <= '0;
      out_seq_c  <= 1'b0;
    end else begin
      if (push) begin
        if (full) ovf_c <= 1'b1;
        else      wp_q  <= wp_q + 1'b1;
      end
      if (rst_s[1]) begin                              // host reset: start clean
        wp_q  <= rp_q;
        ovf_c <= 1'b0;
      end
      case (os_q)
        O_IDLE: if (ack_s[1] == out_seq_c && !empty) os_q <= O_W1;
        O_W1:   os_q <= O_LOAD;                        // rd_q settles
        O_LOAD: begin
          out_data_c <= rd_q;
          rp_q       <= rp_q + 1'b1;
          os_q       <= O_TOG;
        end
        O_TOG: begin                                   // data stable one clock first
          out_seq_c <= ~out_seq_c;
          os_q      <= O_IDLE;
        end
        default: os_q <= O_IDLE;
      endcase
    end
  end

  // ------------------------------------------ host byte -> uart_rx (8N1)
  logic [9:0]  tsh_q;
  logic [3:0]  tbits_q;
  logic [15:0] tcnt_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tsh_q    <= '1;
      tbits_q  <= '0;
      tcnt_q   <= '0;
      in_ack_c <= 1'b0;
    end else if (tbits_q == 0) begin
      tsh_q <= '1;
      if (inseq_s[1] != in_ack_c) begin                // in_data_t is stable
        tsh_q    <= {1'b1, in_data_t, 1'b0};
        tbits_q  <= 4'd10;
        tcnt_q   <= BIT_M1;
        in_ack_c <= inseq_s[1];
      end
    end else if (tcnt_q != 0) begin
      tcnt_q <= tcnt_q - 16'd1;
    end else begin
      tsh_q   <= {1'b1, tsh_q[9:1]};
      tbits_q <= tbits_q - 4'd1;
      tcnt_q  <= BIT_M1;
    end
  end

  assign uart_rx = tsh_q[0];

endmodule
