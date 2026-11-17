// ============================================================================
// id_stage.sv - Decode stage + id_ex pipeline register.
//   Expands RV32C, decodes, generates the immediate, reads the register file
//   (through rs1_addr/rs2_addr), detects ID exceptions (instruction access
//   fault, illegal, ECALL, EBREAK), and requests an ID redirect:
//     BP_MODE >= 1 : JAL -> pc + imm
//     BP_MODE == 1 : conditional branch predicted taken by the BHT
//   An instruction carrying an exception is turned into a NOP (all side-
//   effect flags cleared) for the following stages.
//
// Ports:
//   id_*            : if_id register contents
//   rs1_addr/rs2_addr, rs1_data/rs2_data : register file read port
//   bht_taken       : BHT prediction for id_pc (BP_MODE 1)
//   redirect_req/target : ID redirect request (arbitrated by hazard_unit)
//   use_rs1/use_rs2 : for load-use detection
//   stall_ex/flush_id_ex : pipeline control for the id_ex register
//   fwd_rs1/fwd_rs2 : forwarded EX operands, captured while EX is stalled
//   ex_*            : id_ex register outputs
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module id_stage
#(
  parameter bit ENABLE_M = 1'b1,
  parameter bit ENABLE_C = 1'b1,
  parameter int BP_MODE  = 2
) (
  input  logic        clk,
  input  logic        rst_n,
  // if_id
  input  logic        id_valid,
  input  logic [31:0] id_pc,
  input  logic [31:0] id_insn,
  input  logic        id_is_c,
  input  logic [31:0] id_pred_npc,
  input  logic        id_fault,
  // register file
  output logic [4:0]  rs1_addr,
  output logic [4:0]  rs2_addr,
  input  logic [31:0] rs1_data,
  input  logic [31:0] rs2_data,
  // prediction / redirect
  input  logic        bht_taken,
  output logic        redirect_req,
  output logic [31:0] redirect_target,
  // hazard detection
  output logic        use_rs1,
  output logic        use_rs2,
  // pipeline control
  input  logic        stall_ex,
  input  logic        flush_id_ex,
  input  logic [31:0] fwd_rs1,
  input  logic [31:0] fwd_rs2,
  // id_ex register
  output logic        ex_valid,
  output logic [31:0] ex_pc,
  output logic [31:0] ex_insn,
  output logic        ex_is_c,
  output logic [31:0] ex_pred_npc,
  output logic        ex_exc,
  output logic [3:0]  ex_exc_cause,
  output logic [31:0] ex_exc_tval,
  output logic [4:0]  ex_rs1,
  output logic [4:0]  ex_rs2,
  output logic [31:0] ex_rs1_val,
  output logic [31:0] ex_rs2_val,
  output logic [31:0] ex_imm,
  output logic [4:0]  ex_rd,
  output logic        ex_rd_we,
  output logic [3:0]  ex_alu_op,
  output logic [1:0]  ex_opa_sel,
  output logic        ex_opb_imm,
  output logic [2:0]  ex_funct3,
  output logic        ex_is_branch,
  output logic        ex_is_jal,
  output logic        ex_is_jalr,
  output logic        ex_is_load,
  output logic        ex_is_store,
  output logic        ex_is_md,
  output logic        ex_is_csr,
  output logic        ex_is_mret,
  output logic        ex_is_fence_i
);

  // ---------------- Decompression ----------------
  logic [31:0] c_insn;
  logic        c_illegal;
  logic [31:0] insn32;

  // Instantiated only with the C extension (id_is_c is always 0 otherwise).
  generate
  if (ENABLE_C) begin : g_cdec
    compressed_decoder u_cdec (
      .cinsn  (id_insn[15:0]),
      .insn   (c_insn),
      .illegal(c_illegal)
    );
  end else begin : g_no_cdec
    assign c_insn    = 32'b0;
    assign c_illegal = 1'b1;
  end
  endgenerate

  assign insn32 = id_is_c ? c_insn : id_insn;

  // ---------------- Decode ----------------
  logic        d_illegal, d_use_rs1, d_use_rs2, d_rd_we;
  logic [4:0]  d_rs1, d_rs2, d_rd;
  logic [3:0]  d_alu_op;
  logic [1:0]  d_opa_sel;
  logic        d_opb_imm;
  logic [2:0]  d_imm_type, d_funct3;
  logic        d_branch, d_jal, d_jalr, d_load, d_store, d_md, d_csr;
  logic        d_ecall, d_ebreak, d_mret, d_fence_i;
  logic [31:0] imm;

  decoder #(.ENABLE_M(ENABLE_M)) u_dec (
    .insn      (insn32),
    .illegal   (d_illegal),
    .rs1       (d_rs1),
    .rs2       (d_rs2),
    .rd        (d_rd),
    .use_rs1   (d_use_rs1),
    .use_rs2   (d_use_rs2),
    .rd_we     (d_rd_we),
    .alu_op    (d_alu_op),
    .opa_sel   (d_opa_sel),
    .opb_imm   (d_opb_imm),
    .imm_type  (d_imm_type),
    .funct3    (d_funct3),
    .is_branch (d_branch),
    .is_jal    (d_jal),
    .is_jalr   (d_jalr),
    .is_load   (d_load),
    .is_store  (d_store),
    .is_md     (d_md),
    .is_csr    (d_csr),
    .is_ecall  (d_ecall),
    .is_ebreak (d_ebreak),
    .is_mret   (d_mret),
    .is_fence_i(d_fence_i)
  );

  imm_gen u_imm (
    .insn    (insn32),
    .imm_type(d_imm_type),
    .imm     (imm)
  );

  assign rs1_addr = d_rs1;
  assign rs2_addr = d_rs2;

  // ---------------- Exceptions (priority: fault > illegal > ecall/ebreak) ----
  logic        exc;
  logic [3:0]  exc_cause;
  logic [31:0] exc_tval;
  logic        illegal;

  assign illegal = id_is_c ? c_illegal : d_illegal;

  always_comb begin
    exc       = 1'b1;
    exc_cause = EXC_INSN_ACCESS;
    exc_tval  = 32'b0;
    if (id_fault) begin
      exc_cause = EXC_INSN_ACCESS;
      exc_tval  = id_pc;
    end else if (illegal) begin
      exc_cause = EXC_ILLEGAL;
      exc_tval  = id_is_c ? {16'b0, id_insn[15:0]} : id_insn;
    end else if (d_ecall) begin
      exc_cause = EXC_ECALL_M;
    end else if (d_ebreak) begin
      exc_cause = EXC_BREAKPOINT;
      exc_tval  = id_pc;
    end else begin
      exc       = 1'b0;
    end
  end

  assign use_rs1 = id_valid && !exc && d_use_rs1;
  assign use_rs2 = id_valid && !exc && d_use_rs2;

  // ---------------- ID redirect ----------------
  logic        redir;
  logic [31:0] pred_npc_new;

  assign redirect_target = id_pc + imm;
  assign redir = id_valid && !exc &&
                 (((BP_MODE >= 1) && d_jal) || ((BP_MODE == 1) && d_branch && bht_taken)) &&
                 (ENABLE_C || !redirect_target[1]);
  assign redirect_req = redir && (id_pred_npc != redirect_target);
  assign pred_npc_new = redir ? redirect_target : id_pred_npc;

  // ---------------- id_ex register ----------------
  logic nop;
  assign nop = exc;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_valid      <= 1'b0;
      ex_pc         <= 32'b0;
      ex_insn       <= 32'b0;
      ex_is_c       <= 1'b0;
      ex_pred_npc   <= 32'b0;
      ex_exc        <= 1'b0;
      ex_exc_cause  <= 4'b0;
      ex_exc_tval   <= 32'b0;
      ex_rs1        <= 5'b0;
      ex_rs2        <= 5'b0;
      ex_rs1_val    <= 32'b0;
      ex_rs2_val    <= 32'b0;
      ex_imm        <= 32'b0;
      ex_rd         <= 5'b0;
      ex_rd_we      <= 1'b0;
      ex_alu_op     <= 4'b0;
      ex_opa_sel    <= 2'b0;
      ex_opb_imm    <= 1'b0;
      ex_funct3     <= 3'b0;
      ex_is_branch  <= 1'b0;
      ex_is_jal     <= 1'b0;
      ex_is_jalr    <= 1'b0;
      ex_is_load    <= 1'b0;
      ex_is_store   <= 1'b0;
      ex_is_md      <= 1'b0;
      ex_is_csr     <= 1'b0;
      ex_is_mret    <= 1'b0;
      ex_is_fence_i <= 1'b0;
    end else if (flush_id_ex) begin
      ex_valid      <= 1'b0;
    end else if (stall_ex) begin
      // Hold, but keep operands up to date: producers in MEM/WB may retire
      // while EX waits, so capture the forwarded values.
      ex_rs1_val    <= fwd_rs1;
      ex_rs2_val    <= fwd_rs2;
    end else begin
      ex_valid      <= id_valid;
      ex_pc         <= id_pc;
      ex_insn       <= id_insn;
      ex_is_c       <= id_is_c;
      ex_pred_npc   <= pred_npc_new;
      ex_exc        <= exc;
      ex_exc_cause  <= exc_cause;
      ex_exc_tval   <= exc_tval;
      ex_rs1        <= d_rs1;
      ex_rs2        <= d_rs2;
      ex_rs1_val    <= rs1_data;
      ex_rs2_val    <= rs2_data;
      ex_imm        <= imm;
      ex_rd         <= d_rd;
      ex_rd_we      <= d_rd_we && !nop;
      ex_alu_op     <= d_alu_op;
      ex_opa_sel    <= d_opa_sel;
      ex_opb_imm    <= d_opb_imm;
      ex_funct3     <= d_funct3;
      ex_is_branch  <= d_branch && !nop;
      ex_is_jal     <= d_jal && !nop;
      ex_is_jalr    <= d_jalr && !nop;
      ex_is_load    <= d_load && !nop;
      ex_is_store   <= d_store && !nop;
      ex_is_md      <= d_md && !nop;
      ex_is_csr     <= d_csr && !nop;
      ex_is_mret    <= d_mret && !nop;
      ex_is_fence_i <= d_fence_i && !nop;
    end
  end

endmodule
