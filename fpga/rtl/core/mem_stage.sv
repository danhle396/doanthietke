// ============================================================================
// mem_stage.sv - Memory / commit stage + mem_wb pipeline register.
//   * LSU access on dbus (request held until dbus_ready)
//   * CSR read-modify-write (through csr_file)
//   * Precise traps: synchronous exceptions of the MEM instruction or an
//     interrupt (take_irq). MRET and FENCE.I redirect the front-end here.
//   Exception priority on one instruction:
//     carried (IF/ID/EX) > CSR illegal > load/store misaligned > access fault
//
// Ports:
//   mem_*           : ex_mem register contents
//   dbus_*          : data bus
//   csr_*           : csr_file access; csr_rdata/csr_illegal returned
//   irq_req/irq_cause, trap_target, mepc : from csr_file
//   trap_*, mret    : to csr_file
//   redirect/redirect_target : front-end redirect (trap, MRET, FENCE.I)
//   trap            : MEM instruction trapped (does not retire)
//   bus_wait        : request issued but not yet acknowledged
//   flush_mem_wb    : pipeline control
//   wb_*            : mem_wb register outputs
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module mem_stage
(
  input  logic        clk,
  input  logic        rst_n,
  // ex_mem
  input  logic        mem_valid,
  input  logic [31:0] mem_pc,
  input  logic [31:0] mem_insn,
  input  logic        mem_is_c,
  input  logic        mem_exc,
  input  logic [3:0]  mem_exc_cause,
  input  logic [31:0] mem_exc_tval,
  input  logic [4:0]  mem_rd,
  input  logic        mem_rd_we,
  input  logic [31:0] mem_result,
  input  logic [31:0] mem_opnd,
  input  logic [2:0]  mem_funct3,
  input  logic        mem_is_load,
  input  logic        mem_is_store,
  input  logic        mem_is_csr,
  input  logic        mem_is_mret,
  input  logic        mem_is_fence_i,
  input  logic        mem_is_branch,
  input  logic        mem_is_jump,
  input  logic        mem_mispred,
  // data bus
  output logic        dbus_req,
  output logic        dbus_we,
  output logic [3:0]  dbus_be,
  output logic [31:0] dbus_addr,
  output logic [31:0] dbus_wdata,
  input  logic        dbus_ready,
  input  logic        dbus_err,
  input  logic [31:0] dbus_rdata,
  // csr_file
  output logic        csr_access,
  output logic [11:0] csr_addr,
  output logic [1:0]  csr_op,
  output logic        csr_wr,
  output logic [31:0] csr_operand,
  output logic        csr_commit,
  input  logic [31:0] csr_rdata,
  input  logic        csr_illegal,
  input  logic        irq_req,
  input  logic [3:0]  irq_cause,
  input  logic [31:0] trap_target,
  input  logic [31:0] mepc,
  output logic        trap,
  output logic        trap_irq,
  output logic [3:0]  trap_cause,
  output logic [31:0] trap_tval,
  output logic        mret,
  // control
  output logic        redirect,
  output logic [31:0] redirect_target,
  output logic        bus_wait,
  input  logic        flush_mem_wb,
  // mem_wb register
  output logic        wb_valid,
  output logic [31:0] wb_pc,
  output logic [31:0] wb_insn,
  output logic        wb_is_c,
  output logic [4:0]  wb_rd,
  output logic        wb_rd_we,
  output logic [31:0] wb_result,
  output logic        wb_is_load,
  output logic        wb_is_store,
  output logic [31:0] wb_mem_addr,
  output logic [31:0] wb_store_data,
  output logic [1:0]  wb_mem_size,
  output logic        wb_is_branch,
  output logic        wb_is_jump,
  output logic        wb_mispred,
  output logic        wb_instret_noinc
);

  // ---------------- Interrupt acceptance ----------------
  logic bus_started_q;
  logic take_irq;

  assign take_irq = irq_req && mem_valid && !mem_exc && !bus_started_q;

  // ---------------- LSU ----------------
  logic        misaligned;
  logic [31:0] load_data;
  logic        lsu_valid;

  assign lsu_valid = mem_valid && !mem_exc && !take_irq;

  lsu u_lsu (
    .valid     (lsu_valid),
    .is_load   (mem_is_load),
    .is_store  (mem_is_store),
    .funct3    (mem_funct3),
    .addr      (mem_result),
    .wdata     (mem_opnd),
    .misaligned(misaligned),
    .dbus_req  (dbus_req),
    .dbus_we   (dbus_we),
    .dbus_be   (dbus_be),
    .dbus_addr (dbus_addr),
    .dbus_wdata(dbus_wdata),
    .dbus_rdata(dbus_rdata),
    .load_data (load_data)
  );

  assign bus_wait = dbus_req && !dbus_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)          bus_started_q <= 1'b0;
    else if (dbus_ready) bus_started_q <= 1'b0;
    else if (dbus_req)   bus_started_q <= 1'b1;
  end

  // ---------------- CSR access ----------------
  assign csr_access  = mem_valid && mem_is_csr && !mem_exc;
  assign csr_addr    = mem_insn[31:20];
  assign csr_op      = mem_funct3[1:0];
  assign csr_wr      = (mem_funct3[1:0] == CSR_RW) || (mem_insn[19:15] != 5'd0);
  assign csr_operand = mem_opnd;

  // ---------------- Exceptions ----------------
  logic        lsu_exc, acc_exc, exc;
  logic [3:0]  exc_cause;
  logic [31:0] exc_tval;

  assign lsu_exc = mem_valid && !mem_exc && (mem_is_load || mem_is_store) && misaligned;
  assign acc_exc = dbus_req && dbus_ready && dbus_err;

  always_comb begin
    exc       = 1'b1;
    exc_cause = mem_exc_cause;
    exc_tval  = mem_exc_tval;
    if (mem_valid && mem_exc) begin
      exc_cause = mem_exc_cause;
      exc_tval  = mem_exc_tval;
    end else if (csr_illegal) begin
      exc_cause = EXC_ILLEGAL;
      exc_tval  = mem_insn;
    end else if (lsu_exc) begin
      exc_cause = mem_is_store ? EXC_STORE_MISALIGNED : EXC_LOAD_MISALIGNED;
      exc_tval  = mem_result;
    end else if (acc_exc) begin
      exc_cause = mem_is_store ? EXC_STORE_ACCESS : EXC_LOAD_ACCESS;
      exc_tval  = mem_result;
    end else begin
      exc       = 1'b0;
    end
  end

  assign trap       = take_irq || exc;
  assign trap_irq   = take_irq;
  assign trap_cause = take_irq ? irq_cause : exc_cause;
  assign trap_tval  = take_irq ? 32'b0 : exc_tval;
  assign mret       = mem_valid && mem_is_mret && !trap;
  assign csr_commit = !trap;

  assign redirect = trap || (mem_valid && (mem_is_mret || mem_is_fence_i));
  always_comb begin
    if (trap)             redirect_target = trap_target;
    else if (mem_is_mret) redirect_target = mepc;
    else                  redirect_target = mem_pc + (mem_is_c ? 32'd2 : 32'd4);
  end

  // ---------------- Result ----------------
  logic [31:0] result;
  always_comb begin
    if (mem_is_load)     result = load_data;
    else if (mem_is_csr) result = csr_rdata;
    else                 result = mem_result;
  end

  logic [31:0] store_val;
  always_comb begin
    case (mem_funct3[1:0])
      SZ_B:    store_val = {24'b0, mem_opnd[7:0]};
      SZ_H:    store_val = {16'b0, mem_opnd[15:0]};
      default: store_val = mem_opnd;
    endcase
  end

  // ---------------- mem_wb register ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wb_valid         <= 1'b0;
      wb_pc            <= 32'b0;
      wb_insn          <= 32'b0;
      wb_is_c          <= 1'b0;
      wb_rd            <= 5'b0;
      wb_rd_we         <= 1'b0;
      wb_result        <= 32'b0;
      wb_is_load       <= 1'b0;
      wb_is_store      <= 1'b0;
      wb_mem_addr      <= 32'b0;
      wb_store_data    <= 32'b0;
      wb_mem_size      <= 2'b0;
      wb_is_branch     <= 1'b0;
      wb_is_jump       <= 1'b0;
      wb_mispred       <= 1'b0;
      wb_instret_noinc <= 1'b0;
    end else if (flush_mem_wb) begin
      wb_valid         <= 1'b0;
    end else begin
      wb_valid         <= mem_valid;
      wb_pc            <= mem_pc;
      wb_insn          <= mem_insn;
      wb_is_c          <= mem_is_c;
      wb_rd            <= mem_rd;
      wb_rd_we         <= mem_rd_we;
      wb_result        <= result;
      wb_is_load       <= mem_is_load;
      wb_is_store      <= mem_is_store;
      wb_mem_addr      <= mem_result;
      wb_store_data    <= store_val;
      wb_mem_size      <= mem_funct3[1:0];
      wb_is_branch     <= mem_is_branch;
      wb_is_jump       <= mem_is_jump;
      wb_mispred       <= mem_mispred;
      wb_instret_noinc <= csr_access && csr_wr &&
                          ((csr_addr == CSR_MINSTRET) || (csr_addr == CSR_MINSTRETH));
    end
  end

endmodule
