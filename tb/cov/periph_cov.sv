// periph_cov.sv - functional coverage for the BTB, SPI, UART and every FIFO
// (attached with `bind`, coverage builds only).
`timescale 1ns/1ps

module btb_cov #(parameter int ENTRIES = 32) (
  input logic clk,
  input logic wr_en,
  input logic rd_hit,
  input logic [ENTRIES-1:0] valid_q,
  input logic [$clog2(ENTRIES)-1:0] wr_idx
);
  c_btb_alloc:   cover property (@(posedge clk) wr_en && !valid_q[wr_idx]);
  c_btb_replace: cover property (@(posedge clk) wr_en && valid_q[wr_idx]);
  c_btb_lookup_hit:  cover property (@(posedge clk) rd_hit);
  c_btb_lookup_miss: cover property (@(posedge clk) !rd_hit);
endmodule

bind btb btb_cov #(.ENTRIES(ENTRIES)) u_btb_cov (.clk, .wr_en, .rd_hit, .valid_q, .wr_idx);

module spi_cov (
  input logic       clk,
  input logic       busy,
  input logic [3:0] ctrl_q
);
  c_spi_mode0: cover property (@(posedge clk) busy && ctrl_q[2:1] == 2'b00);
  c_spi_mode1: cover property (@(posedge clk) busy && ctrl_q[2:1] == 2'b10);
  c_spi_mode2: cover property (@(posedge clk) busy && ctrl_q[2:1] == 2'b01);
  c_spi_mode3: cover property (@(posedge clk) busy && ctrl_q[2:1] == 2'b11);
  c_spi_msb:   cover property (@(posedge clk) busy && !ctrl_q[3]);
  c_spi_lsb:   cover property (@(posedge clk) busy && ctrl_q[3]);
endmodule

bind spi_apb spi_cov u_spi_cov (.clk, .busy(eng_busy), .ctrl_q);

module uart_cov (
  input logic       clk,
  input logic       tx_busy,
  input logic       rx_valid,
  input logic [4:0] ctrl_q,
  input logic       err_q
);
  c_uart_8n1:   cover property (@(posedge clk) tx_busy && !ctrl_q[2] && !ctrl_q[4]);
  c_uart_even:  cover property (@(posedge clk) tx_busy && ctrl_q[2] && !ctrl_q[3]);
  c_uart_odd:   cover property (@(posedge clk) tx_busy && ctrl_q[2] && ctrl_q[3]);
  c_uart_stop2: cover property (@(posedge clk) tx_busy && ctrl_q[4]);
  c_uart_rx:    cover property (@(posedge clk) rx_valid);
  c_uart_err:   cover property (@(posedge clk) err_q);
endmodule

bind uart_apb uart_cov u_uart_cov (.clk, .tx_busy, .rx_valid, .ctrl_q, .err_q);

module fifo_cov (
  input logic clk,
  input logic full,
  input logic empty,
  input logic push,
  input logic pop
);
  c_fifo_full:        cover property (@(posedge clk) full);
  c_fifo_empty:       cover property (@(posedge clk) empty);
  c_fifo_push_full:   cover property (@(posedge clk) push && full);
  c_fifo_push_pop:    cover property (@(posedge clk) push && pop && !empty);
endmodule

bind sync_fifo fifo_cov u_fifo_cov (.clk, .full, .empty, .push, .pop);
