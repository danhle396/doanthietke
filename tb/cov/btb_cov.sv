// btb_cov.sv - functional coverage (bind), coverage builds only.
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
