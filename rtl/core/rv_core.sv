// ============================================================================
// rv_core.sv - RV32IMC 5-stage pipelined core (IF ID EX MEM WB).
//   Machine mode only. Zicsr, Zifencei, Zicntr. Configurable branch
//   predictor (BP_MODE 0/1/2). Traps, CSR RMW, MRET and FENCE.I are handled
//   at MEM (commit point).
//
// Ports:
//   ibus_*  : combinational instruction bus (32 bits from a halfword address)
//   dbus_*  : data bus, request held until dbus_ready
//   irq_*   : machine timer / software / external interrupt lines
//   mtime   : value for the time/timeh CSRs
//
// Parameters:
//   RESET_PC, ENABLE_M, ENABLE_C, BP_MODE, BHT_ENTRIES, BTB_ENTRIES
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module rv_core
#(
  parameter logic [31:0] RESET_PC    = 32'h8000_0000,
  parameter bit          ENABLE_M    = 1'b1,
  parameter bit          ENABLE_C    = 1'b1,
  parameter int          BP_MODE     = 2,
  parameter int          BHT_ENTRIES = 256,
  parameter int          BTB_ENTRIES = 32
) (
  input  logic        clk,
  input  logic        rst_n,
  output logic [31:0] ibus_addr,
  input  logic [31:0] ibus_rdata,
  input  logic        ibus_err,
  output logic        dbus_req,
  output logic        dbus_we,
  output logic [3:0]  dbus_be,
  output logic [31:0] dbus_addr,
  output logic [31:0] dbus_wdata,
  input  logic        dbus_ready,
  input  logic        dbus_err,
  input  logic [31:0] dbus_rdata,
  input  logic        irq_mtip,
  input  logic        irq_msip,
  input  logic        irq_meip,
  input  logic [63:0] mtime
);

  // ---------------- Pipeline control ----------------
  logic stall_if, stall_id, stall_ex, stall_mem;
  logic flush_if_id, flush_id_ex, flush_ex_mem, flush_mem_wb;
  logic ex_redirect, id_redirect, mem_redirect, mem_trap;
  logic ev_load_use, ev_md_stall, ev_bus_wait;

  // ---------------- IF / if_id ----------------
  logic [31:0] if_pc;
  logic        bp_if_taken, bp_if_btb_hit;
  logic [31:0] bp_if_target;
  logic        id_valid, id_is_c, id_fault;
  logic [31:0] id_pc, id_insn, id_pred_npc;
  logic [31:0] ex_target, id_target, mem_target;

  // ---------------- ID / id_ex ----------------
  logic [4:0]  rf_raddr1, rf_raddr2;
  logic [31:0] rf_rdata1, rf_rdata2;
  logic        bp_id_taken, id_redirect_req, id_use_rs1, id_use_rs2;
  logic        ex_valid, ex_is_c, ex_exc, ex_rd_we, ex_opb_imm;
  logic [31:0] ex_pc, ex_insn, ex_pred_npc, ex_exc_tval, ex_rs1_val, ex_rs2_val, ex_imm;
  logic [3:0]  ex_exc_cause, ex_alu_op;
  logic [4:0]  ex_rs1, ex_rs2, ex_rd;
  logic [1:0]  ex_opa_sel;
  logic [2:0]  ex_funct3;
  logic        ex_is_branch, ex_is_jal, ex_is_jalr, ex_is_load, ex_is_store;
  logic        ex_is_md, ex_is_csr, ex_is_mret, ex_is_fence_i;

  // ---------------- EX / ex_mem ----------------
  logic [1:0]  fwd_a, fwd_b;
  logic [31:0] fwd_rs1, fwd_rs2;
  logic        ex_mispredict, md_stall, md_busy;
  logic        bp_upd_bht, bp_upd_taken, bp_upd_btb_wr, bp_upd_btb_inv;
  logic [31:0] bp_upd_target;
  logic [1:0]  bp_upd_type;
  logic        mem_valid, mem_is_c, mem_exc, mem_rd_we;
  logic [31:0] mem_pc, mem_insn, mem_exc_tval, mem_result, mem_opnd;
  logic [3:0]  mem_exc_cause;
  logic [4:0]  mem_rd;
  logic [2:0]  mem_funct3;
  logic        mem_is_load, mem_is_store, mem_is_csr, mem_is_mret, mem_is_fence_i;
  logic        mem_is_branch, mem_is_jump, mem_mispred;

  // ---------------- MEM / mem_wb ----------------
  logic        csr_access, csr_wr, csr_commit, csr_illegal;
  logic [11:0] csr_addr;
  logic [1:0]  csr_op;
  logic [31:0] csr_operand, csr_rdata;
  logic        irq_req;
  logic [3:0]  irq_cause;
  logic [31:0] trap_target, mepc;
  logic        trap_irq, mret;
  logic [3:0]  trap_cause;
  logic [31:0] trap_tval;
  logic        bus_wait;
  logic        wb_valid, wb_is_c, wb_rd_we, wb_is_load, wb_is_store;
  logic [31:0] wb_pc, wb_insn, wb_result, wb_mem_addr, wb_store_data;
  logic [4:0]  wb_rd;
  logic [1:0]  wb_mem_size;
  logic        wb_is_branch, wb_is_jump, wb_mispred, wb_instret_noinc;

  // ---------------- WB ----------------
  logic        rf_we;
  logic [4:0]  rf_waddr;
  logic [31:0] rf_wdata;
  logic        retire, instret_inc;
  logic        ev_branch, ev_branch_miss, ev_jump, ev_jump_miss, ev_compressed;

  // =========================================================================
  if_stage #(.RESET_PC(RESET_PC), .ENABLE_C(ENABLE_C)) u_if (
    .clk, .rst_n,
    .ibus_addr, .ibus_rdata, .ibus_err,
    .pc          (if_pc),
    .bp_taken    (bp_if_taken),
    .bp_target   (bp_if_target),
    .mem_redirect(mem_redirect),
    .mem_target  (mem_target),
    .ex_redirect (ex_redirect),
    .ex_target   (ex_target),
    .id_redirect (id_redirect),
    .id_target   (id_target),
    .stall_if, .stall_id, .flush_if_id,
    .id_valid, .id_pc, .id_insn, .id_is_c, .id_pred_npc, .id_fault
  );

  branch_predictor #(
    .BP_MODE(BP_MODE), .BHT_ENTRIES(BHT_ENTRIES), .BTB_ENTRIES(BTB_ENTRIES)
  ) u_bp (
    .clk, .rst_n,
    .if_pc          (if_pc),
    .if_pred_taken  (bp_if_taken),
    .if_pred_target (bp_if_target),
    .if_btb_hit     (bp_if_btb_hit),
    .id_pc          (id_pc),
    .id_bht_taken   (bp_id_taken),
    .upd_pc         (ex_pc),
    .upd_bht        (bp_upd_bht),
    .upd_taken      (bp_upd_taken),
    .upd_btb_wr     (bp_upd_btb_wr),
    .upd_target     (bp_upd_target),
    .upd_type       (bp_upd_type),
    .upd_btb_inv    (bp_upd_btb_inv)
  );

  regfile u_rf (
    .clk, .rst_n,
    .we    (rf_we),
    .waddr (rf_waddr),
    .wdata (rf_wdata),
    .raddr1(rf_raddr1),
    .raddr2(rf_raddr2),
    .rdata1(rf_rdata1),
    .rdata2(rf_rdata2)
  );

  id_stage #(.ENABLE_M(ENABLE_M), .ENABLE_C(ENABLE_C), .BP_MODE(BP_MODE)) u_id (
    .clk, .rst_n,
    .id_valid, .id_pc, .id_insn, .id_is_c, .id_pred_npc, .id_fault,
    .rs1_addr       (rf_raddr1),
    .rs2_addr       (rf_raddr2),
    .rs1_data       (rf_rdata1),
    .rs2_data       (rf_rdata2),
    .bht_taken      (bp_id_taken),
    .redirect_req   (id_redirect_req),
    .redirect_target(id_target),
    .use_rs1        (id_use_rs1),
    .use_rs2        (id_use_rs2),
    .stall_ex, .flush_id_ex,
    .fwd_rs1, .fwd_rs2,
    .ex_valid, .ex_pc, .ex_insn, .ex_is_c, .ex_pred_npc, .ex_exc, .ex_exc_cause,
    .ex_exc_tval, .ex_rs1, .ex_rs2, .ex_rs1_val, .ex_rs2_val, .ex_imm, .ex_rd,
    .ex_rd_we, .ex_alu_op, .ex_opa_sel, .ex_opb_imm, .ex_funct3, .ex_is_branch,
    .ex_is_jal, .ex_is_jalr, .ex_is_load, .ex_is_store, .ex_is_md, .ex_is_csr,
    .ex_is_mret, .ex_is_fence_i
  );

  forward_unit u_fwd (
    .ex_rs1    (ex_rs1),
    .ex_rs2    (ex_rs2),
    .mem_valid (mem_valid),
    .mem_rd_we (mem_rd_we),
    .mem_rd    (mem_rd),
    .mem_no_fwd(mem_is_load || mem_is_csr),
    .wb_valid  (wb_valid),
    .wb_rd_we  (wb_rd_we),
    .wb_rd     (wb_rd),
    .fwd_a     (fwd_a),
    .fwd_b     (fwd_b)
  );

  ex_stage #(.ENABLE_M(ENABLE_M), .ENABLE_C(ENABLE_C)) u_ex (
    .clk, .rst_n,
    .ex_valid, .ex_pc, .ex_insn, .ex_is_c, .ex_pred_npc, .ex_exc, .ex_exc_cause,
    .ex_exc_tval, .ex_rs1, .ex_rs1_val, .ex_rs2_val, .ex_imm, .ex_rd, .ex_rd_we,
    .ex_alu_op, .ex_opa_sel, .ex_opb_imm, .ex_funct3, .ex_is_branch, .ex_is_jal,
    .ex_is_jalr, .ex_is_load, .ex_is_store, .ex_is_md, .ex_is_csr, .ex_is_mret,
    .ex_is_fence_i,
    .fwd_a, .fwd_b,
    .mem_fwd_data   (mem_result),
    .wb_fwd_data    (wb_result),
    .fwd_rs1, .fwd_rs2,
    .mispredict     (ex_mispredict),
    .redirect_target(ex_target),
    .ex_redirect,
    .md_stall, .md_busy,
    .mem_redirect,
    .stall_ex, .stall_mem, .flush_ex_mem,
    .bp_upd_bht, .bp_upd_taken, .bp_upd_btb_wr, .bp_upd_target, .bp_upd_type,
    .bp_upd_btb_inv,
    .mem_valid, .mem_pc, .mem_insn, .mem_is_c, .mem_exc, .mem_exc_cause,
    .mem_exc_tval, .mem_rd, .mem_rd_we, .mem_result, .mem_opnd, .mem_funct3,
    .mem_is_load, .mem_is_store, .mem_is_csr, .mem_is_mret, .mem_is_fence_i,
    .mem_is_branch, .mem_is_jump, .mem_mispred
  );

  mem_stage u_mem (
    .clk, .rst_n,
    .mem_valid, .mem_pc, .mem_insn, .mem_is_c, .mem_exc, .mem_exc_cause,
    .mem_exc_tval, .mem_rd, .mem_rd_we, .mem_result, .mem_opnd, .mem_funct3,
    .mem_is_load, .mem_is_store, .mem_is_csr, .mem_is_mret, .mem_is_fence_i,
    .mem_is_branch, .mem_is_jump, .mem_mispred,
    .dbus_req, .dbus_we, .dbus_be, .dbus_addr, .dbus_wdata, .dbus_ready,
    .dbus_err, .dbus_rdata,
    .csr_access, .csr_addr, .csr_op, .csr_wr, .csr_operand, .csr_commit,
    .csr_rdata, .csr_illegal,
    .irq_req, .irq_cause, .trap_target, .mepc,
    .trap           (mem_trap),
    .trap_irq, .trap_cause, .trap_tval, .mret,
    .redirect       (mem_redirect),
    .redirect_target(mem_target),
    .bus_wait,
    .flush_mem_wb,
    .wb_valid, .wb_pc, .wb_insn, .wb_is_c, .wb_rd, .wb_rd_we, .wb_result,
    .wb_is_load, .wb_is_store, .wb_mem_addr, .wb_store_data, .wb_mem_size,
    .wb_is_branch, .wb_is_jump, .wb_mispred, .wb_instret_noinc
  );

  csr_file #(.ENABLE_M(ENABLE_M), .ENABLE_C(ENABLE_C)) u_csr (
    .clk, .rst_n,
    .csr_access, .csr_addr, .csr_op, .csr_wr, .csr_operand, .csr_commit,
    .csr_rdata, .csr_illegal,
    .trap             (mem_trap),
    .trap_irq, .trap_cause,
    .trap_pc          (mem_pc),
    .trap_tval, .trap_target,
    .mret, .mepc,
    .irq_mtip, .irq_msip, .irq_meip,
    .irq_req, .irq_cause,
    .mtime,
    .instret_inc,
    .instret_rd_bypass(instret_inc),
    .hpm_inc          ({ev_compressed, ev_bus_wait, ev_md_stall, ev_load_use,
                        ev_jump_miss, ev_jump, ev_branch_miss, ev_branch})
  );

  wb_stage u_wb (
    .clk,
    .wb_valid, .wb_pc, .wb_insn, .wb_is_c, .wb_rd, .wb_rd_we, .wb_result,
    .wb_is_load, .wb_is_store, .wb_mem_addr, .wb_store_data, .wb_mem_size,
    .wb_is_branch, .wb_is_jump, .wb_mispred, .wb_instret_noinc,
    .rf_we, .rf_waddr, .rf_wdata,
    .retire, .instret_inc,
    .ev_branch, .ev_branch_miss, .ev_jump, .ev_jump_miss, .ev_compressed
  );

  hazard_unit u_hz (
    .id_valid, .id_use_rs1, .id_use_rs2,
    .id_rs1         (rf_raddr1),
    .id_rs2         (rf_raddr2),
    .id_redirect_req,
    .ex_valid, .ex_is_load, .ex_is_csr, .ex_rd_we, .ex_rd,
    .ex_mispredict,
    .md_stall,
    .bus_wait,
    .mem_redirect,
    .mem_trap,
    .stall_if, .stall_id, .stall_ex, .stall_mem,
    .flush_if_id, .flush_id_ex, .flush_ex_mem, .flush_mem_wb,
    .ex_redirect, .id_redirect,
    .ev_load_use, .ev_md_stall, .ev_bus_wait
  );

  /* verilator lint_off UNUSEDSIGNAL */
  // Observation-only signals (testbench / functional coverage).
  logic unused_obs;
  assign unused_obs = ^{retire, md_busy, bp_if_btb_hit, ex_rs2};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
