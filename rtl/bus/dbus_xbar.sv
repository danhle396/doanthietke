// ============================================================================
// dbus_xbar.sv - Data-bus address decoder.
//   RAM window          -> ram_dp D-port
//   0x1000_0000-0xFFFF  -> apb_bridge
//   anything else       -> immediate error response (ready = 1, err = 1)
//
// Ports:
//   c_*   : from/to the core data bus
//   ram_* : RAM D-port
//   apb_* : APB bridge (same request/response protocol as the core bus)
// Parameters:
//   RAM_BASE, RAM_SIZE (bytes), APB_BASE, APB_SIZE (bytes)
// ============================================================================
module dbus_xbar #(
  parameter logic [31:0] RAM_BASE = 32'h8000_0000,
  parameter logic [31:0] RAM_SIZE = 32'h0002_0000,
  parameter logic [31:0] APB_BASE = 32'h1000_0000,
  parameter logic [31:0] APB_SIZE = 32'h0001_0000
) (
  // core side
  input  logic        c_req,
  input  logic        c_we,
  input  logic [3:0]  c_be,
  input  logic [31:0] c_addr,
  input  logic [31:0] c_wdata,
  output logic        c_ready,
  output logic        c_err,
  output logic [31:0] c_rdata,
  // RAM
  output logic        ram_req,
  output logic        ram_we,
  output logic [3:0]  ram_be,
  output logic [31:0] ram_addr,
  output logic [31:0] ram_wdata,
  input  logic        ram_ready,
  input  logic [31:0] ram_rdata,
  // APB bridge
  output logic        apb_req,
  output logic        apb_we,
  output logic [3:0]  apb_be,
  output logic [31:0] apb_addr,
  output logic [31:0] apb_wdata,
  input  logic        apb_ready,
  input  logic        apb_err,
  input  logic [31:0] apb_rdata
);

  logic in_ram, in_apb;

  assign in_ram = (c_addr >= RAM_BASE) && ((c_addr - RAM_BASE) < RAM_SIZE);
  assign in_apb = (c_addr >= APB_BASE) && ((c_addr - APB_BASE) < APB_SIZE);

  assign ram_req   = c_req && in_ram;
  assign ram_we    = c_we;
  assign ram_be    = c_be;
  assign ram_addr  = c_addr;
  assign ram_wdata = c_wdata;

  assign apb_req   = c_req && in_apb;
  assign apb_we    = c_we;
  assign apb_be    = c_be;
  assign apb_addr  = c_addr;
  assign apb_wdata = c_wdata;

  always_comb begin
    if (in_ram) begin
      c_ready = ram_ready;
      c_err   = 1'b0;
      c_rdata = ram_rdata;
    end else if (in_apb) begin
      c_ready = apb_ready;
      c_err   = apb_err;
      c_rdata = apb_rdata;
    end else begin
      c_ready = c_req;
      c_err   = 1'b1;
      c_rdata = 32'b0;
    end
  end

endmodule
