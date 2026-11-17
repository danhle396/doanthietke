// ============================================================================
// ex_stage.sv - Execute stage + ex_mem pipeline register.
//   Operand forwarding, ALU, branch resolution, MulDiv, misprediction
//   detection (actual_npc != pred_npc, uniform for all BP_MODEs) and
//   predictor update.
//
// Ports:
//   ex_*            : id_ex register contents
//   fwd_a/fwd_b     : forward selects (forward_unit)
//   mem_fwd_data    : ex_mem result (ALU/MulDiv/link)
//   wb_fwd_data     : mem_wb result
//   fwd_rs1/fwd_rs2 : forwarded operand values (also refresh id_ex on stall)
//   mispredict, redirect_target : misprediction request (hazard_unit arbitrates)
//   ex_redirect     : redirect fires this cycle (from hazard_unit)
//   md_stall        : MulDiv result not ready
//   mem_redirect    : older trap/mret/fence.i (kills this instruction)
//   bp_upd_*        : predictor update
//   stall_ex/stall_mem/flush_ex_mem : pipeline control
//   mem_*           : ex_mem register outputs
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module ex_stage
#(
  parameter bit ENABLE_M = 1'b1,
  parameter bit ENABLE_C = 1'b1
) (
  input  logic        clk,
  input  logic        rst_n,
  // id_ex
  input  logic        ex_valid,
  input  logic [31:0] ex_pc,
  input  logic [31:0] ex_insn,
  input  logic        ex_is_c,
  input  logic [31:0] ex_pred_npc,
  input  logic        ex_exc,
  input  logic [3:0]  ex_exc_cause,
  input  logic [31:0] ex_exc_tval,
  input  logic [4:0]  ex_rs1,
  input  logic [31:0] ex_rs1_val,
  input  logic [31:0] ex_rs2_val,
  input  logic [31:0] ex_imm,
  input  logic [4:0]  ex_rd,
  input  logic        ex_rd_we,
  input  logic [3:0]  ex_alu_op,
  input  logic [1:0]  ex_opa_sel,
  input  logic        ex_opb_imm,
  input  logic [2:0]  ex_funct3,
  input  logic        ex_is_branch,
  input  logic        ex_is_jal,
  input  logic        ex_is_jalr,
  input  logic        ex_is_load,
  input  logic        ex_is_store,
  input  logic        ex_is_md,
  input  logic        ex_is_csr,
  input  logic        ex_is_mret,
  input  logic        ex_is_fence_i,
  // forwarding
  input  logic [1:0]  fwd_a,
  input  logic [1:0]  fwd_b,
  input  logic [31:0] mem_fwd_data,
  input  logic [31:0] wb_fwd_data,
  output logic [31:0] fwd_rs1,
  output logic [31:0] fwd_rs2,
  // control
  output logic        mispredict,
  output logic [31:0] redirect_target,
  input  logic        ex_redirect,
  output logic        md_stall,
  output logic        md_busy,
  input  logic        mem_redirect,
  input  logic        stall_ex,
  input  logic        stall_mem,
  input  logic        flush_ex_mem,
  // predictor update
  output logic        bp_upd_bht,
  output logic        bp_upd_taken,
  output logic        bp_upd_btb_wr,
  output logic [31:0] bp_upd_target,
  output logic [1:0]  bp_upd_type,
  output logic        bp_upd_btb_inv,
  // ex_mem register
  output logic        mem_valid,
  output logic [31:0] mem_pc,
  output logic [31:0] mem_insn,
  output logic        mem_is_c,
  output logic        mem_exc,
  output logic [3:0]  mem_exc_cause,
  output logic [31:0] mem_exc_tval,
  output logic [4:0]  mem_rd,
  output logic        mem_rd_we,
  output logic [31:0] mem_result,
  output logic [31:0] mem_opnd,
  output logic [2:0]  mem_funct3,
  output logic        mem_is_load,
  output logic        mem_is_store,
  output logic        mem_is_csr,
  output logic        mem_is_mret,
  output logic        mem_is_fence_i,
  output logic        mem_is_branch,
  output logic        mem_is_jump,
  output logic        mem_mispred
);

  // ---------------- Forwarding muxes ----------------
  always_comb begin
    case (fwd_a)
      2'd1:    fwd_rs1 = mem_fwd_data;
      2'd2:    fwd_rs1 = wb_fwd_data;
      default: fwd_rs1 = ex_rs1_val;
    endcase
    case (fwd_b)
      2'd1:    fwd_rs2 = mem_fwd_data;
      2'd2:    fwd_rs2 = wb_fwd_data;
      default: fwd_rs2 = ex_rs2_val;
    endcase
  end

  // ---------------- ALU ----------------
  logic [31:0] opa, opb, alu_res;

  always_comb begin
    case (ex_opa_sel)
      OPA_PC:   opa = ex_pc;
      OPA_ZERO: opa = 32'b0;
      default:  opa = fwd_rs1;
    endcase
  end
  assign opb = ex_opb_imm ? ex_imm : fwd_rs2;

  alu u_alu (
    .op    (ex_alu_op),
    .a     (opa),
    .b     (opb),
    .result(alu_res)
  );

  // ---------------- Branch ----------------
  logic        taken;
  logic [31:0] target, link, actual_npc;

  branch_unit u_br (
    .pc        (ex_pc),
    .imm       (ex_imm),
    .rs1       (fwd_rs1),
    .rs2       (fwd_rs2),
    .is_branch (ex_is_branch),
    .is_jal    (ex_is_jal),
    .is_jalr   (ex_is_jalr),
    .funct3    (ex_funct3),
    .is_c      (ex_is_c),
    .taken     (taken),
    .target    (target),
    .link      (link),
    .actual_npc(actual_npc)
  );

  // ---------------- MulDiv ----------------
  logic        md_ready;
  logic [31:0] md_res;

  // Instantiated only with the M extension (ENABLE_M = 0 removes it entirely;
  // M encodings are then illegal and ex_is_md is never set).
  generate
  if (ENABLE_M) begin : g_md
    muldiv u_md (
      .clk,
      .rst_n,
      .valid  (ex_valid && ex_is_md),
      .op     (ex_funct3),
      .a      (fwd_rs1),
      .b      (fwd_rs2),
      .kill   (mem_redirect),
      .advance(!stall_ex),
      .ready  (md_ready),
      .result (md_res),
      .busy   (md_busy)
    );
  end else begin : g_no_md
    assign md_ready = 1'b1;
    assign md_res   = 32'b0;
    assign md_busy  = 1'b0;
  end
  endgenerate

  assign md_stall = ex_valid && ex_is_md && !md_ready;

  // ---------------- Exceptions / misprediction ----------------
  logic misalign;   // taken target not 4-byte aligned without C
  logic exc_any;
  logic is_cti;
  logic fire;       // instruction leaves EX this cycle and is not flushed

  assign is_cti   = ex_is_branch || ex_is_jal || ex_is_jalr;
  assign misalign = !ENABLE_C && ex_valid && !ex_exc && taken && target[1];
  assign exc_any  = ex_exc || misalign;

  assign mispredict      = ex_valid && !exc_any && (actual_npc != ex_pred_npc);
  assign redirect_target = actual_npc;

  assign fire = ex_valid && !exc_any && !stall_ex && !mem_redirect;

  assign bp_upd_bht     = fire && ex_is_branch;
  assign bp_upd_taken   = taken;
  assign bp_upd_btb_wr  = fire && taken;
  assign bp_upd_target  = target;
  assign bp_upd_type    = ex_is_jal ? BT_JAL : (ex_is_jalr ? BT_JALR : BT_BRANCH);
  assign bp_upd_btb_inv = fire && !is_cti && (ex_pred_npc != link);

  logic [31:0] result;
  assign result = ex_is_md ? md_res : ((ex_is_jal || ex_is_jalr) ? link : alu_res);

  // ---------------- ex_mem register ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_valid      <= 1'b0;
      mem_pc         <= 32'b0;
      mem_insn       <= 32'b0;
      mem_is_c       <= 1'b0;
      mem_exc        <= 1'b0;
      mem_exc_cause  <= 4'b0;
      mem_exc_tval   <= 32'b0;
      mem_rd         <= 5'b0;
      mem_rd_we      <= 1'b0;
      mem_result     <= 32'b0;
      mem_opnd       <= 32'b0;
      mem_funct3     <= 3'b0;
      mem_is_load    <= 1'b0;
      mem_is_store   <= 1'b0;
      mem_is_csr     <= 1'b0;
      mem_is_mret    <= 1'b0;
      mem_is_fence_i <= 1'b0;
      mem_is_branch  <= 1'b0;
      mem_is_jump    <= 1'b0;
      mem_mispred    <= 1'b0;
    end else if (flush_ex_mem) begin
      mem_valid      <= 1'b0;
    end else if (!stall_mem) begin
      mem_valid      <= ex_valid;
      mem_pc         <= ex_pc;
      mem_insn       <= ex_insn;
      mem_is_c       <= ex_is_c;
      mem_exc        <= exc_any;
      mem_exc_cause  <= ex_exc ? ex_exc_cause : EXC_INSN_MISALIGNED;
      mem_exc_tval   <= ex_exc ? ex_exc_tval : target;
      mem_rd         <= ex_rd;
      mem_rd_we      <= ex_rd_we && !misalign;
      mem_result     <= result;
      mem_opnd       <= ex_is_csr ? (ex_funct3[2] ? {27'b0, ex_rs1} : fwd_rs1) : fwd_rs2;
      mem_funct3     <= ex_funct3;
      mem_is_load    <= ex_is_load;
      mem_is_store   <= ex_is_store;
      mem_is_csr     <= ex_is_csr;
      mem_is_mret    <= ex_is_mret;
      mem_is_fence_i <= ex_is_fence_i;
      mem_is_branch  <= ex_is_branch && !misalign;
      mem_is_jump    <= (ex_is_jal || ex_is_jalr) && !misalign;
      mem_mispred    <= ex_redirect;
    end
  end

endmodule
