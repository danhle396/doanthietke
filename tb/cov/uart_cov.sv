`timescale 1ns/1ps

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
