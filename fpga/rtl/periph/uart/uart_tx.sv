// ============================================================================
// uart_tx.sv - UART transmitter (8 data bits, LSB first, optional parity,
//   1 or 2 stop bits). Bit time = 16 x (baud_div + 1) clocks, counted by a
//   private prescaler that restarts with every frame (exact bit lengths).
//
// Ports:
//   baud_div     : BAUD_DIV register
//   en           : CTRL.TX_EN - start new frames only when set
//   parity_en/odd, stop2 : frame format (sampled at frame start)
//   data_valid/data : next byte available (TX FIFO not empty)
//   data_pop     : byte taken from the FIFO (one clk)
//   tx           : serial output (idle = 1)
//   busy         : frame in progress
// ============================================================================
module uart_tx (
  input  logic       clk,
  input  logic       rst_n,
  input  logic [15:0] baud_div,
  input  logic       en,
  input  logic       parity_en,
  input  logic       parity_odd,
  input  logic       stop2,
  input  logic       data_valid,
  input  logic [7:0] data,
  output logic       data_pop,
  output logic       tx,
  output logic       busy
);

  typedef enum logic [2:0] {T_IDLE, T_START, T_DATA, T_PARITY, T_STOP} state_e;
  state_e     state_q;
  logic [3:0] tick_q;     // ticks within the current bit
  logic [2:0] bit_q;      // data bit index / stop bit index
  logic [7:0] shift_q;
  logic       par_q;      // running parity of the data bits
  logic       pen_q, podd_q, stop2_q;
  logic [15:0] pre_q;     // clock prescaler -> one tick per (baud_div + 1) clocks
  logic       tick16;

  assign tick16 = (pre_q == baud_div);

  assign busy     = (state_q != T_IDLE);
  assign data_pop = (state_q == T_IDLE) && en && data_valid;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= T_IDLE;
      tick_q  <= 4'd0;
      bit_q   <= 3'd0;
      shift_q <= 8'd0;
      par_q   <= 1'b0;
      pen_q   <= 1'b0;
      podd_q  <= 1'b0;
      stop2_q <= 1'b0;
      tx      <= 1'b1;
      pre_q   <= 16'd0;
    end else begin
      pre_q <= (tick16 || state_q == T_IDLE) ? 16'd0 : pre_q + 16'd1;
      case (state_q)
        T_IDLE: begin
          tx <= 1'b1;
          if (data_pop) begin
            state_q <= T_START;
            shift_q <= data;
            par_q   <= 1'b0;
            pen_q   <= parity_en;
            podd_q  <= parity_odd;
            stop2_q <= stop2;
            tick_q  <= 4'd0;
            tx      <= 1'b0;  // start bit
          end
        end
        default: begin
          if (tick16) begin
            tick_q <= tick_q + 4'd1;
            if (tick_q == 4'd15) begin  // end of the current bit
              case (state_q)
                T_START: begin
                  state_q <= T_DATA;
                  bit_q   <= 3'd0;
                  tx      <= shift_q[0];
                  par_q   <= shift_q[0];
                  shift_q <= {1'b0, shift_q[7:1]};
                end
                T_DATA: begin
                  if (bit_q == 3'd7) begin
                    if (pen_q) begin
                      state_q <= T_PARITY;
                      tx      <= par_q ^ podd_q;  // even: total ones even
                    end else begin
                      state_q <= T_STOP;
                      bit_q   <= 3'd0;
                      tx      <= 1'b1;
                    end
                  end else begin
                    bit_q   <= bit_q + 3'd1;
                    tx      <= shift_q[0];
                    par_q   <= par_q ^ shift_q[0];
                    shift_q <= {1'b0, shift_q[7:1]};
                  end
                end
                T_PARITY: begin
                  state_q <= T_STOP;
                  bit_q   <= 3'd0;
                  tx      <= 1'b1;
                end
                default: begin  // T_STOP
                  if (stop2_q && bit_q == 3'd0) begin
                    bit_q <= 3'd1;
                  end else begin
                    state_q <= T_IDLE;
                  end
                end
              endcase
            end
          end
        end
      endcase
    end
  end

endmodule
