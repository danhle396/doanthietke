// spi_slave_bfm.sv - SPI slave BFM, all four modes, MSB or LSB first.
//   Returns bytes from tx_pattern (queue) or, when it is empty, the
//   predefined sequence pattern_byte(n) = 8'hA5 ^ (n * 8'd29). Every byte
//   received from MOSI is stored in rx_q. Configure cpol/cpha/lsb_first
//   before asserting CS. MISO is driven only while cs_n = 0 (else 0).
`timescale 1ns/1ps

module spi_slave_bfm (
  input  logic sclk,
  input  logic mosi,
  input  logic cs_n,
  output logic miso
);

  bit   cpol = 0, cpha = 0, lsb_first = 0;
  byte  tx_pattern[$];
  byte  rx_q[$];
  byte  tx_log[$];      // bytes actually returned (for checking)
  int   n_tx = 0;
  int   n_sample, n_drive;
  logic [7:0] cur_tx, cur_rx;

  initial miso = 1'b0;

  function automatic byte pattern_byte(input int n);
    return 8'hA5 ^ 8'(n * 29);
  endfunction

  function automatic logic [7:0] next_tx();
    logic [7:0] b;
    b = (tx_pattern.size() != 0) ? tx_pattern.pop_front() : pattern_byte(n_tx);
    n_tx++;
    tx_log.push_back(b);
    return b;
  endfunction

  function automatic logic bit_of(input logic [7:0] b, input int k);
    return lsb_first ? b[k] : b[7 - k];
  endfunction

  always @(negedge cs_n) begin
    n_sample = 0;
    n_drive  = 0;
    if (!cpha) begin
      cur_tx = next_tx();
      miso = bit_of(cur_tx, 0);
      n_drive = 1;
    end
  end

  always @(posedge cs_n) miso = 1'b0;

  always @(sclk) begin
    if (cs_n === 1'b0) begin
      if (sclk !== cpol) begin  // leading edge
        if (!cpha) sample();
        else begin
          if (n_drive == 0) cur_tx = next_tx();
          miso = bit_of(cur_tx, n_drive);
          n_drive = (n_drive + 1) % 8;
        end
      end else begin            // trailing edge
        if (!cpha) begin
          if (n_sample == 0) begin  // byte just completed: start the next one
            cur_tx = next_tx();
            miso = bit_of(cur_tx, 0);
            n_drive = 1;
          end else begin
            miso = bit_of(cur_tx, n_drive);
            n_drive++;
          end
        end else sample();
      end
    end
  end

  task automatic sample();
    if (lsb_first) cur_rx[n_sample] = mosi;
    else           cur_rx[7 - n_sample] = mosi;
    n_sample++;
    if (n_sample == 8) begin
      rx_q.push_back(cur_rx);
      n_sample = 0;
    end
  endtask

endmodule
