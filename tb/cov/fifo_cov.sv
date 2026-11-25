`timescale 1ns/1ps

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
