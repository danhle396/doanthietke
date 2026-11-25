module hazard_unit (
  input  logic       id_valid,
  input  logic       id_use_rs1,
  input  logic       id_use_rs2,
  input  logic [4:0] id_rs1,
  input  logic [4:0] id_rs2,
  input  logic       id_redirect_req,
  input  logic       ex_valid,
  input  logic       ex_is_load,
  input  logic       ex_is_csr,
  input  logic       ex_rd_we,
  input  logic [4:0] ex_rd,
  input  logic       ex_mispredict,
  input  logic       md_stall,
  input  logic       bus_wait,
  input  logic       mem_redirect,
  input  logic       mem_trap,
  output logic       stall_if,
  output logic       stall_id,
  output logic       stall_ex,
  output logic       stall_mem,
  output logic       flush_if_id,
  output logic       flush_id_ex,
  output logic       flush_ex_mem,
  output logic       flush_mem_wb,
  output logic       ex_redirect,
  output logic       id_redirect,
  output logic       ev_load_use,
  output logic       ev_md_stall,
  output logic       ev_bus_wait
);

  logic load_use;

  assign load_use = id_valid && ex_valid && (ex_is_load || ex_is_csr) && ex_rd_we &&
                    (ex_rd != 5'd0) &&
                    ((id_use_rs1 && (id_rs1 == ex_rd)) || (id_use_rs2 && (id_rs2 == ex_rd)));

  assign stall_mem = bus_wait;
  assign stall_ex  = bus_wait || md_stall;
  assign stall_id  = stall_ex || load_use;
  assign stall_if  = stall_id;

  assign ex_redirect = ex_mispredict && !stall_ex && !mem_redirect;
  assign id_redirect = id_redirect_req && !stall_id && !ex_redirect && !mem_redirect;

  assign flush_if_id  = mem_redirect || ex_redirect || id_redirect;
  assign flush_id_ex  = mem_redirect || ex_redirect || (stall_id && !stall_ex);
  assign flush_ex_mem = mem_redirect || (stall_ex && !stall_mem);
  assign flush_mem_wb = mem_trap || stall_mem;

  assign ev_load_use = load_use && !stall_ex && !mem_redirect;
  assign ev_md_stall = md_stall && !bus_wait && !mem_redirect;
  assign ev_bus_wait = bus_wait;

endmodule
