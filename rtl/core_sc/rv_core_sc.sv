// ============================================================================
// rv_core_sc.sv - Single-cycle RV32I + Zicsr + Zifencei reference core.
//   Same port list as rv_core. Every instruction completes in one cycle
//   (fetch -> decode -> execute -> memory -> write-back are combinational);
//   the whole core stalls while dbus_ready = 0. Reuses decoder, imm_gen, alu,
//   branch_unit, lsu, regfile, csr_file and wb_stage (commit log) of rv_core.
//   ENABLE_M / ENABLE_C are fixed to 0 (M and 16-bit encodings are illegal).
//
// Ports: see rv_core (section 4.2 of the spec).
// Parameters:
//   RESET_PC : reset program counter
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module rv_core_sc
#(
  parameter logic [31:0] RESET_PC = 32'h8000_0000
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

  logic [31:0] pc_q, insn;

  assign ibus_addr = pc_q;
  assign insn      = ibus_rdata;

  // ---------------- Decode ----------------
  logic        d_illegal, d_use_rs1, d_use_rs2, d_rd_we, d_opb_imm;
  logic [4:0]  d_rs1, d_rs2, d_rd;
  logic [3:0]  d_alu_op;
  logic [1:0]  d_opa_sel;
  logic [2:0]  d_imm_type, d_funct3;
  logic        d_branch, d_jal, d_jalr, d_load, d_store, d_md, d_csr;
  logic        d_ecall, d_ebreak, d_mret, d_fence_i;
  logic [31:0] imm;

  decoder #(.ENABLE_M(1'b0)) u_dec (
    .insn(insn), .illegal(d_illegal), .rs1(d_rs1), .rs2(d_rs2), .rd(d_rd),
    .use_rs1(d_use_rs1), .use_rs2(d_use_rs2), .rd_we(d_rd_we), .alu_op(d_alu_op),
    .opa_sel(d_opa_sel), .opb_imm(d_opb_imm), .imm_type(d_imm_type), .funct3(d_funct3),
    .is_branch(d_branch), .is_jal(d_jal), .is_jalr(d_jalr), .is_load(d_load),
    .is_store(d_store), .is_md(d_md), .is_csr(d_csr), .is_ecall(d_ecall),
    .is_ebreak(d_ebreak), .is_mret(d_mret), .is_fence_i(d_fence_i)
  );

  imm_gen u_imm (.insn(insn), .imm_type(d_imm_type), .imm(imm));

  // ---------------- Register file ----------------
  logic        rf_we;
  logic [4:0]  rf_waddr;
  logic [31:0] rf_wdata, rs1_val, rs2_val;

  regfile #(.WRITE_THROUGH(1'b0)) u_rf (
    .clk, .rst_n,
    .we(rf_we), .waddr(rf_waddr), .wdata(rf_wdata),
    .raddr1(d_rs1), .raddr2(d_rs2), .rdata1(rs1_val), .rdata2(rs2_val)
  );

  // ---------------- Execute ----------------
  logic [31:0] opa, opb, alu_res;
  always_comb begin
    case (d_opa_sel)
      OPA_PC:   opa = pc_q;
      OPA_ZERO: opa = 32'b0;
      default:  opa = rs1_val;
    endcase
  end
  assign opb = d_opb_imm ? imm : rs2_val;

  alu u_alu (.op(d_alu_op), .a(opa), .b(opb), .result(alu_res));

  logic        taken;
  logic [31:0] target, link, actual_npc;
  branch_unit u_br (
    .pc(pc_q), .imm(imm), .rs1(rs1_val), .rs2(rs2_val), .is_branch(d_branch),
    .is_jal(d_jal), .is_jalr(d_jalr), .funct3(d_funct3), .is_c(1'b0),
    .taken(taken), .target(target), .link(link), .actual_npc(actual_npc)
  );

  // ---------------- CSR / interrupts ----------------
  logic        csr_access, csr_wr, csr_illegal, irq_req, take_irq, trap, mret;
  logic [31:0] csr_rdata, trap_target, mepc, csr_operand;
  logic [3:0]  irq_cause, trap_cause;
  logic [31:0] trap_tval;
  logic        bus_started_q;
  logic        instret_inc, retire;
  logic        ev_branch, ev_jump, ev_bus_wait;

  // ---------------- Exceptions (priority order) ----------------
  logic        pre_exc;          // detected before the memory access
  logic [3:0]  pre_cause;
  logic [31:0] pre_tval;
  logic        misaligned, lsu_exc, acc_exc, exc;
  logic [3:0]  exc_cause;
  logic [31:0] exc_tval, load_data;

  always_comb begin
    pre_exc   = 1'b1;
    pre_cause = EXC_INSN_ACCESS;
    pre_tval  = 32'b0;
    if (ibus_err) begin
      pre_cause = EXC_INSN_ACCESS;
      pre_tval  = pc_q;
    end else if (d_illegal || csr_illegal) begin
      pre_cause = EXC_ILLEGAL;
      pre_tval  = insn;
    end else if (d_ecall) begin
      pre_cause = EXC_ECALL_M;
    end else if (d_ebreak) begin
      pre_cause = EXC_BREAKPOINT;
      pre_tval  = pc_q;
    end else if (taken && target[1]) begin
      pre_cause = EXC_INSN_MISALIGNED;
      pre_tval  = target;
    end else begin
      pre_exc   = 1'b0;
    end
  end

  assign take_irq = irq_req && !bus_started_q;

  lsu u_lsu (
    .valid     (!ibus_err && !pre_exc && !take_irq),
    .is_load   (d_load),
    .is_store  (d_store),
    .funct3    (d_funct3),
    .addr      (alu_res),
    .wdata     (rs2_val),
    .misaligned(misaligned),
    .dbus_req, .dbus_we, .dbus_be, .dbus_addr, .dbus_wdata, .dbus_rdata,
    .load_data (load_data)
  );

  logic stall;
  assign stall   = dbus_req && !dbus_ready;
  assign lsu_exc = !pre_exc && (d_load || d_store) && misaligned;
  assign acc_exc = dbus_req && dbus_ready && dbus_err;

  always_comb begin
    exc       = 1'b1;
    exc_cause = pre_cause;
    exc_tval  = pre_tval;
    if (pre_exc) begin
      exc_cause = pre_cause;
      exc_tval  = pre_tval;
    end else if (lsu_exc) begin
      exc_cause = d_store ? EXC_STORE_MISALIGNED : EXC_LOAD_MISALIGNED;
      exc_tval  = alu_res;
    end else if (acc_exc) begin
      exc_cause = d_store ? EXC_STORE_ACCESS : EXC_LOAD_ACCESS;
      exc_tval  = alu_res;
    end else begin
      exc       = 1'b0;
    end
  end

  assign trap       = !stall && (take_irq || exc);
  assign trap_cause = take_irq ? irq_cause : exc_cause;
  assign trap_tval  = take_irq ? 32'b0 : exc_tval;
  assign mret       = !stall && !trap && d_mret;
  assign retire     = rst_n && !stall && !trap;

  assign csr_access  = d_csr && !ibus_err;
  assign csr_wr      = (d_funct3[1:0] == CSR_RW) || (d_rs1 != 5'd0);
  assign csr_operand = d_funct3[2] ? {27'b0, d_rs1} : rs1_val;
  assign instret_inc = retire && !(csr_access && csr_wr &&
                       ((imm[11:0] == CSR_MINSTRET) || (imm[11:0] == CSR_MINSTRETH)));

  assign ev_branch   = retire && d_branch;
  assign ev_jump     = retire && (d_jal || d_jalr);
  assign ev_bus_wait = stall;

  csr_file #(.ENABLE_M(1'b0), .ENABLE_C(1'b0)) u_csr (
    .clk, .rst_n,
    .csr_access, .csr_addr(imm[11:0]), .csr_op(d_funct3[1:0]), .csr_wr,
    .csr_operand, .csr_commit(retire), .csr_rdata, .csr_illegal,
    .trap, .trap_irq(take_irq), .trap_cause, .trap_pc(pc_q), .trap_tval, .trap_target,
    .mret, .mepc,
    .irq_mtip, .irq_msip, .irq_meip, .irq_req, .irq_cause,
    .mtime,
    .instret_inc,
    .instret_rd_bypass(1'b0),
    .hpm_inc({1'b0, ev_bus_wait, 2'b00, 1'b0, ev_jump, 1'b0, ev_branch})
  );

  // ---------------- Next PC ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)         pc_q <= RESET_PC;
    else if (stall)     pc_q <= pc_q;
    else if (trap)      pc_q <= trap_target;
    else if (mret)      pc_q <= mepc;
    else                pc_q <= actual_npc;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)          bus_started_q <= 1'b0;
    else if (dbus_ready) bus_started_q <= 1'b0;
    else if (dbus_req)   bus_started_q <= 1'b1;
  end

  // ---------------- Write-back (+ commit log) ----------------
  logic [31:0] result;
  always_comb begin
    if (d_load)               result = load_data;
    else if (d_csr)           result = csr_rdata;
    else if (d_jal || d_jalr) result = link;
    else                      result = alu_res;
  end

  logic [31:0] store_val;
  always_comb begin
    case (d_funct3[1:0])
      SZ_B:    store_val = {24'b0, rs2_val[7:0]};
      SZ_H:    store_val = {16'b0, rs2_val[15:0]};
      default: store_val = rs2_val;
    endcase
  end

  /* verilator lint_off UNUSEDSIGNAL */
  // Retired-event outputs of wb_stage not needed here (no compressed/mispredict).
  logic wb_retire, wb_instret, ev_b, ev_bm, ev_j, ev_jm, ev_c;
  /* verilator lint_on UNUSEDSIGNAL */

  wb_stage u_wb (
    .clk,
    .wb_valid        (retire),
    .wb_pc           (pc_q),
    .wb_insn         (insn),
    .wb_is_c         (1'b0),
    .wb_rd           (d_rd),
    .wb_rd_we        (d_rd_we),
    .wb_result       (result),
    .wb_is_load      (d_load),
    .wb_is_store     (d_store),
    .wb_mem_addr     (alu_res),
    .wb_store_data   (store_val),
    .wb_mem_size     (d_funct3[1:0]),
    .wb_is_branch    (d_branch),
    .wb_is_jump      (d_jal || d_jalr),
    .wb_mispred      (1'b0),
    .wb_instret_noinc(1'b0),
    .rf_we, .rf_waddr, .rf_wdata,
    .retire          (wb_retire),
    .instret_inc     (wb_instret),
    .ev_branch       (ev_b),
    .ev_branch_miss  (ev_bm),
    .ev_jump         (ev_j),
    .ev_jump_miss    (ev_jm),
    .ev_compressed   (ev_c)
  );

  /* verilator lint_off UNUSEDSIGNAL */
  // Decoder outputs not needed by a single-cycle datapath.
  logic unused;
  assign unused = ^{d_use_rs1, d_use_rs2, d_md, d_fence_i};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
