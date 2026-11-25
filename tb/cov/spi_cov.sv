`timescale 1ns/1ps

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
