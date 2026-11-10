// ============================================================================
// forward_unit.sv - Operand forwarding selects for the EX stage.
//   Sources: ex_mem (ALU / MulDiv / link only - not load/CSR, whose data is
//   produced in MEM) and mem_wb (any result). ex_mem has priority because it
//   holds the younger (more recent) write to the same register.
//
// Ports:
//   ex_rs1/ex_rs2           : source registers of the instruction in EX
//   mem_valid/rd_we/rd      : producer in MEM
//   mem_no_fwd              : MEM producer is a load/CSR (value not ready)
//   wb_valid/rd_we/rd       : producer in WB
//   fwd_a/fwd_b             : 0 = register value, 1 = ex_mem, 2 = mem_wb
// ============================================================================
module forward_unit (
  input  logic [4:0] ex_rs1,
  input  logic [4:0] ex_rs2,
  input  logic       mem_valid,
  input  logic       mem_rd_we,
  input  logic [4:0] mem_rd,
  input  logic       mem_no_fwd,
  input  logic       wb_valid,
  input  logic       wb_rd_we,
  input  logic [4:0] wb_rd,
  output logic [1:0] fwd_a,
  output logic [1:0] fwd_b
);

  localparam logic [1:0] FWD_NONE = 2'd0;
  localparam logic [1:0] FWD_MEM  = 2'd1;
  localparam logic [1:0] FWD_WB   = 2'd2;

  logic mem_ok, wb_ok;
  assign mem_ok = mem_valid && mem_rd_we && (mem_rd != 5'd0) && !mem_no_fwd;
  assign wb_ok  = wb_valid && wb_rd_we && (wb_rd != 5'd0);

  always_comb begin
    if (mem_ok && mem_rd == ex_rs1)     fwd_a = FWD_MEM;
    else if (wb_ok && wb_rd == ex_rs1)  fwd_a = FWD_WB;
    else                                fwd_a = FWD_NONE;
    if (mem_ok && mem_rd == ex_rs2)     fwd_b = FWD_MEM;
    else if (wb_ok && wb_rd == ex_rs2)  fwd_b = FWD_WB;
    else                                fwd_b = FWD_NONE;
  end

endmodule
