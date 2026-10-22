// apb_master_bfm.sv - APB4 master BFM for peripheral unit testbenches.
//   apb_write(addr, data, strb) / apb_read(addr, data, err) follow the
//   SETUP -> ACCESS sequence and wait for PREADY. Signals change on negedge.
`timescale 1ns/1ps

module apb_master_bfm (
  input  logic        clk,
  output logic        psel,
  output logic        penable,
  output logic        pwrite,
  output logic [11:0] paddr,
  output logic [31:0] pwdata,
  output logic [3:0]  pstrb,
  input  logic [31:0] prdata,
  input  logic        pready,
  input  logic        pslverr
);

  logic last_err;

  initial begin
    psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0; pstrb = 0; last_err = 0;
  end

  task automatic apb_write(input logic [11:0] addr, input logic [31:0] data,
                           input logic [3:0] strb = 4'hF);
    @(negedge clk);
    psel = 1; penable = 0; pwrite = 1; paddr = addr; pwdata = data; pstrb = strb;
    @(negedge clk);
    penable = 1;
    @(posedge clk);
    while (!pready) @(posedge clk);
    last_err = pslverr;
    @(negedge clk);
    psel = 0; penable = 0; pwrite = 0; pstrb = 0;
  endtask

  task automatic apb_read(input logic [11:0] addr, output logic [31:0] data,
                          output logic err);
    @(negedge clk);
    psel = 1; penable = 0; pwrite = 0; paddr = addr; pstrb = 0;
    @(negedge clk);
    penable = 1;
    @(posedge clk);
    while (!pready) @(posedge clk);
    data = prdata;
    err = pslverr;
    last_err = pslverr;
    @(negedge clk);
    psel = 0; penable = 0;
  endtask

  task automatic idle(input int n);
    repeat (n) @(negedge clk);
  endtask

endmodule
