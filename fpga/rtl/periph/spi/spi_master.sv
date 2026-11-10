// ============================================================================
// spi_master.sv - SPI master shift engine (8-bit frames, modes 0-3,
//   MSB or LSB first). SCLK half period = clk_div + 1 clocks.
//   Edges are numbered 0..15 per byte; even = leading, odd = trailing.
//     CPHA = 0: first bit on MOSI before the first edge, sample MISO on the
//               leading edge, shift MOSI on the trailing edge.
//     CPHA = 1: shift MOSI on the leading edge, sample on the trailing edge.
//   After the 16th edge one more half period elapses (gap), then the byte
//   is delivered and the next TX byte (if any) starts.
//
// Ports:
//   en, cpol, cpha, lsb_first, clk_div : configuration (CTRL / CLK_DIV)
//   tx_valid/tx_data/tx_pop : TX FIFO side
//   rx_valid/rx_data        : received byte (one-clk pulse)
//   busy                    : transfer in progress
//   last                    : with rx_valid: TX FIFO was empty (end of a burst)
//   sclk, mosi, miso        : SPI pins
// ============================================================================
module spi_master (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        en,
  input  logic        cpol,
  input  logic        cpha,
  input  logic        lsb_first,
  input  logic [15:0] clk_div,
  input  logic        tx_valid,
  input  logic [7:0]  tx_data,
  output logic        tx_pop,
  output logic        rx_valid,
  output logic [7:0]  rx_data,
  output logic        busy,
  output logic        last,
  output logic        sclk,
  output logic        mosi,
  input  logic        miso
);

  typedef enum logic [1:0] {S_IDLE, S_XFER, S_GAP} state_e;
  state_e      state_q;
  logic [15:0] cnt_q;
  logic [3:0]  edge_q;
  logic [7:0]  tx_sh_q, rx_sh_q;
  logic        cpha_q, lsb_q;
  logic        half;   // half period elapsed
  logic        start;

  function automatic logic [7:0] rev8(input logic [7:0] x);
    for (int i = 0; i < 8; i++) rev8[i] = x[7 - i];
  endfunction

  // bit-order conversion outside the clocked process (Yosys-friendly)
  logic [7:0] tx_ord, rx_ord;
  assign tx_ord = lsb_first ? rev8(tx_data) : tx_data;
  assign rx_ord = lsb_q ? rev8(rx_sh_q) : rx_sh_q;

  assign half   = (cnt_q == clk_div);
  assign start  = en && tx_valid && ((state_q == S_IDLE) || (state_q == S_GAP && half));
  assign tx_pop = start;
  assign busy   = (state_q != S_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q  <= S_IDLE;
      cnt_q    <= 16'd0;
      edge_q   <= 4'd0;
      tx_sh_q  <= 8'd0;
      rx_sh_q  <= 8'd0;
      cpha_q   <= 1'b0;
      lsb_q    <= 1'b0;
      sclk     <= 1'b0;
      mosi     <= 1'b0;
      rx_valid <= 1'b0;
      rx_data  <= 8'd0;
      last     <= 1'b0;
    end else begin
      rx_valid <= 1'b0;
      last     <= 1'b0;
      cnt_q    <= (half || state_q == S_IDLE) ? 16'd0 : cnt_q + 16'd1;
      if (state_q == S_IDLE) sclk <= cpol;

      // byte delivery at the end of the gap
      if (state_q == S_GAP && half) begin
        rx_valid <= 1'b1;
        rx_data  <= rx_ord;
        last     <= !tx_valid;  // TX FIFO empty: this was the last byte
        state_q  <= S_IDLE;
      end

      if (start) begin
        state_q <= S_XFER;
        cnt_q   <= 16'd0;
        edge_q  <= 4'd0;
        cpha_q  <= cpha;
        lsb_q   <= lsb_first;
        tx_sh_q <= tx_ord;
        sclk    <= cpol;
        if (!cpha) mosi <= tx_ord[7];
      end else if (state_q == S_XFER && half) begin
        sclk   <= !sclk;
        edge_q <= edge_q + 4'd1;
        if (!edge_q[0]) begin            // leading edge
          if (!cpha_q) rx_sh_q <= {rx_sh_q[6:0], miso};
          else begin
            mosi    <= tx_sh_q[7];
            tx_sh_q <= {tx_sh_q[6:0], 1'b0};
          end
        end else begin                   // trailing edge
          if (!cpha_q) begin
            mosi    <= tx_sh_q[6];
            tx_sh_q <= {tx_sh_q[6:0], 1'b0};
          end else rx_sh_q <= {rx_sh_q[6:0], miso};
        end
        if (edge_q == 4'd15) state_q <= S_GAP;
      end
    end
  end

endmodule
