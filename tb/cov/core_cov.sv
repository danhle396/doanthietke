// core_cov.sv - functional coverage points for rv_core, attached with `bind`
// (coverage builds only: --coverage-user). Each `cover property` becomes a
// named point in coverage.dat; scripts/cov_report.py prints hit / not hit.
`timescale 1ns/1ps

module core_cov (
  input logic        clk,
  input logic        rst_n,
  // retirement
  input logic        wb_valid,
  input logic [31:0] wb_insn,
  input logic [31:0] wb_pc,
  input logic        wb_is_c,
  input logic        wb_mispred,
  // forwarding / hazards
  input logic        ex_valid,
  input logic [1:0]  fwd_a,
  input logic [1:0]  fwd_b,
  input logic        ex_is_load,
  input logic        ex_is_csr,
  input logic        ev_load_use,
  input logic        md_stall,
  input logic        md_busy,
  input logic        bus_wait,
  // prediction
  input logic        ex_redirect,
  input logic        id_redirect,
  input logic        ex_is_branch,
  input logic        ex_is_jal,
  input logic        ex_is_jalr,
  input logic        bp_upd_btb_inv,
  input logic        bp_if_btb_hit,
  // traps
  input logic        mem_valid,
  input logic        mem_trap,
  input logic        trap_irq,
  input logic [3:0]  trap_cause,
  input logic        irq_req
);

  logic [6:0] opc;
  logic       is_m;
  assign opc  = wb_insn[6:0];
  assign is_m = (opc == 7'b0110011) && (wb_insn[31:25] == 7'b0000001) && !wb_is_c;

  // ---- opcode groups retired (32-bit encodings; compressed counted apart) ----
  c_ret_lui:    cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0110111);
  c_ret_auipc:  cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0010111);
  c_ret_jal:    cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b1101111);
  c_ret_jalr:   cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b1100111);
  c_ret_branch: cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b1100011);
  c_ret_load:   cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0000011);
  c_ret_store:  cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0100011);
  c_ret_opimm:  cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0010011);
  c_ret_op:     cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0110011 && !is_m);
  c_ret_fence:  cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0001111 && wb_insn[14:12] == 3'b000);
  c_ret_fencei: cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b0001111 && wb_insn[14:12] == 3'b001);
  c_ret_csr:    cover property (@(posedge clk) wb_valid && !wb_is_c && opc == 7'b1110011 && wb_insn[14:12] != 3'b000);
  c_ret_mret:   cover property (@(posedge clk) wb_valid && !wb_is_c && wb_insn == 32'h3020_0073);
  c_ret_compressed: cover property (@(posedge clk) wb_valid && wb_is_c);
  // ---- each M instruction ----
  c_m_mul:    cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd0);
  c_m_mulh:   cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd1);
  c_m_mulhsu: cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd2);
  c_m_mulhu:  cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd3);
  c_m_div:    cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd4);
  c_m_divu:   cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd5);
  c_m_rem:    cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd6);
  c_m_remu:   cover property (@(posedge clk) wb_valid && is_m && wb_insn[14:12] == 3'd7);
  // 32-bit instruction straddling a word boundary
  c_insn32_straddle: cover property (@(posedge clk) wb_valid && !wb_is_c && wb_pc[1]);

  // ---- forwarding paths ----
  c_fwd_exmem_rs1: cover property (@(posedge clk) ex_valid && fwd_a == 2'd1);
  c_fwd_exmem_rs2: cover property (@(posedge clk) ex_valid && fwd_b == 2'd1);
  c_fwd_memwb_rs1: cover property (@(posedge clk) ex_valid && fwd_a == 2'd2);
  c_fwd_memwb_rs2: cover property (@(posedge clk) ex_valid && fwd_b == 2'd2);
  // ---- stalls ----
  c_stall_load_use: cover property (@(posedge clk) ev_load_use && ex_is_load);
  c_stall_csr_use:  cover property (@(posedge clk) ev_load_use && ex_is_csr);
  c_stall_muldiv:   cover property (@(posedge clk) md_stall);
  c_stall_bus:      cover property (@(posedge clk) bus_wait);

  // ---- prediction ----
  c_mispred_branch: cover property (@(posedge clk) ex_redirect && ex_is_branch);
  c_mispred_jal:    cover property (@(posedge clk) ex_redirect && ex_is_jal);
  c_mispred_jalr:   cover property (@(posedge clk) ex_redirect && ex_is_jalr);
  c_mispred_btb_alias: cover property (@(posedge clk) bp_upd_btb_inv);
  c_id_redirect:    cover property (@(posedge clk) id_redirect);
  c_btb_hit:        cover property (@(posedge clk) bp_if_btb_hit);

  // ---- traps: every mcause ----
  c_exc_insn_misaligned: cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd0);
  c_exc_insn_access:     cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd1);
  c_exc_illegal:         cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd2);
  c_exc_breakpoint:      cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd3);
  c_exc_load_misaligned: cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd4);
  c_exc_load_access:     cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd5);
  c_exc_store_misaligned:cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd6);
  c_exc_store_access:    cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd7);
  c_exc_ecall:           cover property (@(posedge clk) mem_trap && !trap_irq && trap_cause == 4'd11);
  c_irq_msi:             cover property (@(posedge clk) mem_trap && trap_irq && trap_cause == 4'd3);
  c_irq_mti:             cover property (@(posedge clk) mem_trap && trap_irq && trap_cause == 4'd7);
  c_irq_mei:             cover property (@(posedge clk) mem_trap && trap_irq && trap_cause == 4'd11);
  // interrupt pending while the divider iterates
  c_irq_during_div:      cover property (@(posedge clk) irq_req && md_busy);
  // trap of the first correct-path instruction after a mispredicted branch/jump:
  // after ex_redirect the branch itself reaches MEM first, the next valid MEM
  // instruction is the redirect target.
  logic [1:0] after_mis;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)                     after_mis <= 2'd0;
    else if (ex_redirect)           after_mis <= 2'd2;
    else if (mem_valid && after_mis != 2'd0) after_mis <= after_mis - 2'd1;
  end
  c_trap_after_mispred:  cover property (@(posedge clk) after_mis == 2'd1 && mem_valid && mem_trap);

endmodule

bind rv_core core_cov u_core_cov (
  .clk, .rst_n,
  .wb_valid, .wb_insn, .wb_pc, .wb_is_c, .wb_mispred,
  .ex_valid, .fwd_a, .fwd_b, .ex_is_load, .ex_is_csr, .ev_load_use, .md_stall, .md_busy,
  .bus_wait,
  .ex_redirect, .id_redirect, .ex_is_branch, .ex_is_jal, .ex_is_jalr, .bp_upd_btb_inv,
  .bp_if_btb_hit,
  .mem_valid, .mem_trap, .trap_irq, .trap_cause, .irq_req
);
