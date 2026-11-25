/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module csr_file
#(
  parameter bit ENABLE_M = 1'b1,
  parameter bit ENABLE_C = 1'b1
) (
  input  logic        clk,
  input  logic        rst_n,
  // CSR instruction
  input  logic        csr_access,
  input  logic [11:0] csr_addr,
  input  logic [1:0]  csr_op,
  input  logic        csr_wr,
  input  logic [31:0] csr_operand,
  input  logic        csr_commit,
  output logic [31:0] csr_rdata,
  output logic        csr_illegal,
  // trap / return
  input  logic        trap,
  input  logic        trap_irq,
  input  logic [3:0]  trap_cause,
  input  logic [31:0] trap_pc,
  input  logic [31:0] trap_tval,
  output logic [31:0] trap_target,
  input  logic        mret,
  output logic [31:0] mepc,
  // interrupts
  input  logic        irq_mtip,
  input  logic        irq_msip,
  input  logic        irq_meip,
  output logic        irq_req,
  output logic [3:0]  irq_cause,
  // counters
  input  logic [63:0] mtime,
  input  logic        instret_inc,
  input  logic        instret_rd_bypass,
  input  logic [7:0]  hpm_inc
);

  localparam logic [31:0] MISA_VAL = 32'h4000_0100
                                   | (ENABLE_M ? 32'h0000_1000 : 32'h0)
                                   | (ENABLE_C ? 32'h0000_0004 : 32'h0);
  localparam logic [31:0] EPC_MASK = ENABLE_C ? 32'hFFFF_FFFE : 32'hFFFF_FFFC;

  // ---------------- State ----------------
  logic        mstatus_mie, mstatus_mpie;
  logic        mie_meie, mie_mtie, mie_msie;
  logic [31:0] mtvec_q;
  logic [31:0] mepc_q, mcause_q, mtval_q, mscratch_q;
  logic [63:0] mcycle_q, minstret_q;
  logic        inhibit_cy, inhibit_ir;
  logic [63:0] hpm_q [3:10];

  logic [31:0] mstatus_val, mip_val, mie_val;
  logic [63:0] minstret_rd;
  logic [31:0] wdata;
  logic        do_write;

  assign mstatus_val = {19'b0, 2'b11, 3'b0, mstatus_mpie, 3'b0, mstatus_mie, 3'b0};
  assign mip_val     = {20'b0, irq_meip, 3'b0, irq_mtip, 3'b0, irq_msip, 3'b0};
  assign mie_val     = {20'b0, mie_meie, 3'b0, mie_mtie, 3'b0, mie_msie, 3'b0};
  assign minstret_rd = minstret_q + {63'b0, instret_rd_bypass && !inhibit_ir};

  // ---------------- Read mux / existence ----------------
  logic [63:0] hpm_sel;
  always_comb begin
    hpm_sel = 64'b0;
    for (int i = 3; i <= 10; i++)
      if (csr_addr[3:0] == 4'(i)) hpm_sel = hpm_q[i];
  end

  logic exists;
  always_comb begin
    exists    = 1'b1;
    csr_rdata = 32'b0;
    case (csr_addr)
      CSR_MSTATUS:       csr_rdata = mstatus_val;
      CSR_MSTATUSH:      csr_rdata = 32'b0;
      CSR_MISA:          csr_rdata = MISA_VAL;
      CSR_MIE:           csr_rdata = mie_val;
      CSR_MTVEC:         csr_rdata = mtvec_q;
      CSR_MCOUNTINHIBIT: csr_rdata = {29'b0, inhibit_ir, 1'b0, inhibit_cy};
      CSR_MSCRATCH:      csr_rdata = mscratch_q;
      CSR_MEPC:          csr_rdata = mepc_q;
      CSR_MCAUSE:        csr_rdata = mcause_q;
      CSR_MTVAL:         csr_rdata = mtval_q;
      CSR_MIP:           csr_rdata = mip_val;
      CSR_MCYCLE,   CSR_CYCLE:    csr_rdata = mcycle_q[31:0];
      CSR_MCYCLEH,  CSR_CYCLEH:   csr_rdata = mcycle_q[63:32];
      CSR_MINSTRET, CSR_INSTRET:  csr_rdata = minstret_rd[31:0];
      CSR_MINSTRETH,CSR_INSTRETH: csr_rdata = minstret_rd[63:32];
      CSR_TIME:          csr_rdata = mtime[31:0];
      CSR_TIMEH:         csr_rdata = mtime[63:32];
      CSR_MVENDORID, CSR_MARCHID, CSR_MIMPID, CSR_MHARTID, CSR_MCONFIGPTR:
                         csr_rdata = 32'b0;
      default: begin
        if (csr_addr >= CSR_MHPMCOUNTER3 && csr_addr <= CSR_MHPMCOUNTER10)
          csr_rdata = hpm_sel[31:0];
        else if (csr_addr >= CSR_MHPMCOUNTER3H && csr_addr <= CSR_MHPMCOUNTER10H)
          csr_rdata = hpm_sel[63:32];
        else if (csr_addr >= CSR_MHPMEVENT3 && csr_addr <= CSR_MHPMEVENT10)
          csr_rdata = 32'b0;
        else
          exists = 1'b0;
      end
    endcase
  end

  assign csr_illegal = csr_access && (!exists || (csr_wr && (csr_addr[11:10] == 2'b11)));

  always_comb begin
    case (csr_op)
      CSR_RS:  wdata = csr_rdata | csr_operand;
      CSR_RC:  wdata = csr_rdata & ~csr_operand;
      default: wdata = csr_operand;
    endcase
  end

  assign do_write = csr_commit && csr_access && csr_wr && !csr_illegal;

  // ---------------- Interrupts ----------------
  logic pend_mei, pend_msi, pend_mti;
  assign pend_mei = irq_meip && mie_meie;
  assign pend_msi = irq_msip && mie_msie;
  assign pend_mti = irq_mtip && mie_mtie;
  assign irq_req  = mstatus_mie && (pend_mei || pend_msi || pend_mti);

  always_comb begin
    if (pend_mei)      irq_cause = IRQ_MEI;
    else if (pend_msi) irq_cause = IRQ_MSI;
    else               irq_cause = IRQ_MTI;
  end

  // ---------------- Trap target ----------------
  always_comb begin
    if (mtvec_q[0] && trap_irq)
      trap_target = {mtvec_q[31:2], 2'b00} + {26'b0, trap_cause, 2'b00};
    else
      trap_target = {mtvec_q[31:2], 2'b00};
  end

  assign mepc = mepc_q;

  // ---------------- Sequential state ----------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mstatus_mie  <= 1'b0;
      mstatus_mpie <= 1'b0;
      mie_meie     <= 1'b0;
      mie_mtie     <= 1'b0;
      mie_msie     <= 1'b0;
      mtvec_q      <= 32'b0;
      mepc_q       <= 32'b0;
      mcause_q     <= 32'b0;
      mtval_q      <= 32'b0;
      mscratch_q   <= 32'b0;
      inhibit_cy   <= 1'b0;
      inhibit_ir   <= 1'b0;
    end else if (trap) begin
      mepc_q       <= trap_pc & EPC_MASK;
      mcause_q     <= {trap_irq, 27'b0, trap_cause};
      mtval_q      <= trap_tval;
      mstatus_mpie <= mstatus_mie;
      mstatus_mie  <= 1'b0;
    end else if (mret) begin
      mstatus_mie  <= mstatus_mpie;
      mstatus_mpie <= 1'b1;
    end else if (do_write) begin
      case (csr_addr)
        CSR_MSTATUS: begin
          mstatus_mie  <= wdata[3];
          mstatus_mpie <= wdata[7];
        end
        CSR_MIE: begin
          mie_meie <= wdata[11];
          mie_mtie <= wdata[7];
          mie_msie <= wdata[3];
        end
        CSR_MTVEC:         mtvec_q    <= {wdata[31:2], 1'b0, wdata[0]};
        CSR_MCOUNTINHIBIT: begin
          inhibit_cy <= wdata[0];
          inhibit_ir <= wdata[2];
        end
        CSR_MSCRATCH:      mscratch_q <= wdata;
        CSR_MEPC:          mepc_q     <= wdata & EPC_MASK;
        CSR_MCAUSE:        mcause_q   <= wdata;
        CSR_MTVAL:         mtval_q    <= wdata;
        default: ;
      endcase
    end
  end

  // Counters: an explicit CSR write takes precedence over the increment.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mcycle_q   <= 64'b0;
      minstret_q <= 64'b0;
    end else begin
      if (do_write && csr_addr == CSR_MCYCLE)
        mcycle_q <= {mcycle_q[63:32], wdata};
      else if (do_write && csr_addr == CSR_MCYCLEH)
        mcycle_q <= {wdata, mcycle_q[31:0]};
      else if (!inhibit_cy)
        mcycle_q <= mcycle_q + 64'd1;

      if (do_write && csr_addr == CSR_MINSTRET)
        minstret_q <= {minstret_rd[63:32], wdata};
      else if (do_write && csr_addr == CSR_MINSTRETH)
        minstret_q <= {wdata, minstret_rd[31:0]};
      else if (instret_inc && !inhibit_ir)
        minstret_q <= minstret_q + 64'd1;
    end
  end

  genvar gi;
  generate
  for (gi = 3; gi <= 10; gi = gi + 1) begin : g_hpm
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)            hpm_q[gi] <= 64'b0;
      else if (hpm_inc[gi-3]) hpm_q[gi] <= hpm_q[gi] + 64'd1;
    end
  end
  endgenerate

endmodule
