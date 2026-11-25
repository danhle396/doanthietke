/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module lsu
(
  input  logic        valid,
  input  logic        is_load,
  input  logic        is_store,
  input  logic [2:0]  funct3,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  output logic        misaligned,
  output logic        dbus_req,
  output logic        dbus_we,
  output logic [3:0]  dbus_be,
  output logic [31:0] dbus_addr,
  output logic [31:0] dbus_wdata,
  input  logic [31:0] dbus_rdata,
  output logic [31:0] load_data
);

  logic [1:0]  size;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [31:0] shifted;  // only the low halfword is used for LB/LH
  /* verilator lint_on UNUSEDSIGNAL */

  assign size = funct3[1:0];

  always_comb begin
    case (size)
      SZ_B:    misaligned = 1'b0;
      SZ_H:    misaligned = addr[0];
      default: misaligned = (addr[1:0] != 2'b00);
    endcase
  end

  always_comb begin
    case (size)
      SZ_B:    dbus_be = 4'b0001 << addr[1:0];
      SZ_H:    dbus_be = addr[1] ? 4'b1100 : 4'b0011;
      default: dbus_be = 4'b1111;
    endcase
    case (size)
      SZ_B:    dbus_wdata = {4{wdata[7:0]}};
      SZ_H:    dbus_wdata = {2{wdata[15:0]}};
      default: dbus_wdata = wdata;
    endcase
  end

  assign dbus_req  = valid && (is_load || is_store) && !misaligned;
  assign dbus_we   = is_store;
  assign dbus_addr = addr;

  assign shifted = dbus_rdata >> {addr[1:0], 3'b000};

  always_comb begin
    case (funct3)
      3'b000:  load_data = {{24{shifted[7]}}, shifted[7:0]};    // LB
      3'b001:  load_data = {{16{shifted[15]}}, shifted[15:0]};  // LH
      3'b100:  load_data = {24'b0, shifted[7:0]};               // LBU
      3'b101:  load_data = {16'b0, shifted[15:0]};              // LHU
      default: load_data = dbus_rdata;                          // LW
    endcase
  end

endmodule
