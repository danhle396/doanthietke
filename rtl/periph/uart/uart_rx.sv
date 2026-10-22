// ============================================================================
// uart_rx.sv - UART receiver: 2-FF synchronizer, 16x oversampling.
//   A falling edge in IDLE restarts the prescaler; the start bit is checked
//   again at its middle (8 ticks) - a glitch returns to IDLE (false start).
//   Data, parity and the (first) stop bit are sampled in the middle of the
//   bit (every 16 ticks). The byte is delivered with its error flags when
//   the stop bit is sampled.
//
// Ports:
//   baud_div  : BAUD_DIV register (tick every baud_div + 1 clocks)
//   en        : CTRL.RX_EN
//   parity_en/odd : frame format (sampled at the start bit)
//   rx        : serial input (asynchronous)
//   valid     : one-clk pulse, data/frame_err/parity_err valid
// ============================================================================
module uart_rx (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [15:0] baud_div,
  input  logic        en,
  input  logic        parity_en,
  input  logic        parity_odd,
  input  logic        rx,
  output logic        valid,
  output logic [7:0]  data,
  output logic        frame_err,
  output logic        parity_err
);

  typedef enum logic [2:0] {R_IDLE, R_START, R_DATA, R_PARITY, R_STOP} state_e;
  state_e      state_q;
  logic [1:0]  sync_q;
  logic        rx_s;
  logic [15:0] pre_q;
  logic        tick;
  logic [3:0]  tick_q;
  logic [2:0]  bit_q;
  logic [7:0]  shift_q;
  logic        pen_q, podd_q, par_err_q;

  assign rx_s = sync_q[1];
  assign tick = (pre_q == baud_div);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) sync_q <= 2'b11;
    else        sync_q <= {sync_q[0], rx};
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q    <= R_IDLE;
      pre_q      <= 16'd0;
      tick_q     <= 4'd0;
      bit_q      <= 3'd0;
      shift_q    <= 8'd0;
      pen_q      <= 1'b0;
      podd_q     <= 1'b0;
      par_err_q  <= 1'b0;
      valid      <= 1'b0;
      data       <= 8'd0;
      frame_err  <= 1'b0;
      parity_err <= 1'b0;
    end else begin
      valid <= 1'b0;
      pre_q <= (tick || state_q == R_IDLE) ? 16'd0 : pre_q + 16'd1;
      case (state_q)
        R_IDLE: begin
          if (en && !rx_s) begin
            state_q <= R_START;
            tick_q  <= 4'd0;
            pen_q   <= parity_en;
            podd_q  <= parity_odd;
          end
        end
        R_START: begin
          if (tick) begin
            tick_q <= tick_q + 4'd1;
            if (tick_q == 4'd7) begin      // middle of the start bit
              if (!rx_s) begin
                state_q <= R_DATA;
                tick_q  <= 4'd0;
                bit_q   <= 3'd0;
              end else begin
                state_q <= R_IDLE;          // false start
              end
            end
          end
        end
        R_DATA: begin
          if (tick) begin
            tick_q <= tick_q + 4'd1;
            if (tick_q == 4'd15) begin     // middle of a data bit
              shift_q <= {rx_s, shift_q[7:1]};
              bit_q   <= bit_q + 3'd1;
              if (bit_q == 3'd7) state_q <= pen_q ? R_PARITY : R_STOP;
            end
          end
        end
        R_PARITY: begin
          if (tick) begin
            tick_q <= tick_q + 4'd1;
            if (tick_q == 4'd15) begin
              par_err_q <= ((^shift_q) ^ rx_s) != podd_q;
              state_q   <= R_STOP;
            end
          end
        end
        default: begin  // R_STOP
          if (tick) begin
            tick_q <= tick_q + 4'd1;
            if (tick_q == 4'd15) begin
              valid      <= 1'b1;
              data       <= shift_q;
              frame_err  <= !rx_s;
              parity_err <= pen_q && par_err_q;
              par_err_q  <= 1'b0;
              state_q    <= R_IDLE;
            end
          end
        end
      endcase
    end
  end

endmodule
