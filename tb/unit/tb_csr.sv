// tb_csr.sv - csr_file: reset values, CSRRW/RS/RC on every writable CSR with
// WARL masks, read-only/non-existent CSR -> illegal, trap entry / MRET,
// direct and vectored trap targets, interrupt priority, counters
// (mcycle, minstret with bypass + write precedence, mcountinhibit, mhpm,
// time). A second instance checks ENABLE_M = ENABLE_C = 0 (misa, mepc mask).
`timescale 1ns/1ps
`include "tb_common.svh"

module tb_csr;
  import rv_pkg::*;
  `TB_DECLS

  logic        clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  logic        csr_access, csr_wr, csr_commit, csr_illegal;
  logic [11:0] csr_addr;
  logic [1:0]  csr_op;
  logic [31:0] csr_operand, csr_rdata;
  logic        trap, trap_irq, mret, irq_mtip, irq_msip, irq_meip, irq_req;
  logic [3:0]  trap_cause, irq_cause;
  logic [31:0] trap_pc, trap_tval, trap_target, mepc;
  logic [63:0] mtime;
  logic        instret_inc, instret_rd_bypass;
  logic [7:0]  hpm_inc;

  csr_file #(.ENABLE_M(1), .ENABLE_C(1)) dut (.*);

  // second instance: no M, no C (only the combinational outputs are checked)
  logic [31:0] rdata_nc, target_nc, mepc_nc;
  logic        ill_nc, irq_nc;
  logic [3:0]  cause_nc;
  csr_file #(.ENABLE_M(0), .ENABLE_C(0)) dut_nc (
    .clk, .rst_n, .csr_access, .csr_addr, .csr_op, .csr_wr, .csr_operand, .csr_commit,
    .csr_rdata(rdata_nc), .csr_illegal(ill_nc), .trap, .trap_irq, .trap_cause, .trap_pc,
    .trap_tval, .trap_target(target_nc), .mret, .mepc(mepc_nc), .irq_mtip, .irq_msip,
    .irq_meip, .irq_req(irq_nc), .irq_cause(cause_nc), .mtime, .instret_inc,
    .instret_rd_bypass, .hpm_inc);

  task automatic idle();
    csr_access = 0; csr_commit = 0; trap = 0; mret = 0; csr_wr = 0;
  endtask

  // one CSR instruction: returns old value and illegal flag, commits at the edge
  task automatic csr(input logic [11:0] a, input logic [1:0] op, input logic [31:0] v,
                     input logic wr, output logic [31:0] old, output logic ill);
    @(negedge clk);
    csr_access = 1; csr_addr = a; csr_op = op; csr_operand = v; csr_wr = wr; csr_commit = 1;
    #1;
    old = csr_rdata;
    ill = csr_illegal;
    @(negedge clk);
    idle();
  endtask

  task automatic rd(input logic [11:0] a, input logic [31:0] exp, input string what);
    logic [31:0] v;
    logic ill;
    csr(a, CSR_RS, 0, 0, v, ill);
    `CHECK(!ill && v === exp, $sformatf("%s (csr %03x) read %08x exp %08x ill=%0d", what, a, v, exp, ill))
  endtask

  task automatic wr_rd(input logic [11:0] a, input logic [31:0] v, input logic [31:0] exp,
                       input string what);
    logic [31:0] o;
    logic ill;
    csr(a, CSR_RW, v, 1, o, ill);
    `CHECK(!ill, $sformatf("%s write illegal", what))
    rd(a, exp, what);
  endtask

  task automatic expect_illegal(input logic [11:0] a, input logic wr, input string what);
    logic [31:0] o;
    logic ill;
    csr(a, wr ? CSR_RW : CSR_RS, 32'h1, wr, o, ill);
    `CHECK(ill, $sformatf("%s (csr %03x wr=%0d) must be illegal", what, a, wr))
  endtask

  task automatic do_trap(input logic irq, input logic [3:0] cause, input logic [31:0] pc,
                         input logic [31:0] tval, output logic [31:0] target);
    @(negedge clk);
    trap = 1; trap_irq = irq; trap_cause = cause; trap_pc = pc; trap_tval = tval;
    #1;
    target = trap_target;
    @(negedge clk);
    trap = 0;
  endtask

  `TB_TIMEOUT(5ms)

  initial begin
    logic [31:0] v, t;
    logic ill;
    `TB_INIT
    idle();
    csr_addr = 0; csr_op = 0; csr_operand = 0; trap_irq = 0; trap_cause = 0; trap_pc = 0;
    trap_tval = 0; irq_mtip = 0; irq_msip = 0; irq_meip = 0; mtime = 64'h1234_5678_9ABC_DEF0;
    instret_inc = 0; instret_rd_bypass = 0; hpm_inc = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;

    // ---------------- reset values / constants ----------------
    rd(CSR_MSTATUS, 32'h0000_1800, "mstatus reset (MPP=11)");
    rd(CSR_MISA, 32'h4000_1104, "misa");
    `CHECK(rdata_nc == 32'h4000_0100, "misa without M/C")
    rd(CSR_MIE, 0, "mie reset");
    rd(CSR_MTVEC, 0, "mtvec reset");
    rd(CSR_MVENDORID, 0, "mvendorid"); rd(CSR_MARCHID, 0, "marchid");
    rd(CSR_MIMPID, 0, "mimpid");       rd(CSR_MHARTID, 0, "mhartid");
    rd(CSR_MCONFIGPTR, 0, "mconfigptr"); rd(CSR_MSTATUSH, 0, "mstatush");
    rd(CSR_MCOUNTINHIBIT, 0, "mcountinhibit"); rd(CSR_MHPMEVENT3, 0, "mhpmevent3");
    rd(CSR_TIME, 32'h9ABC_DEF0, "time"); rd(CSR_TIMEH, 32'h1234_5678, "timeh");

    // ---------------- RW / RS / RC and WARL masks ----------------
    wr_rd(CSR_MSCRATCH, 32'hA5A5_5A5A, 32'hA5A5_5A5A, "mscratch");
    csr(CSR_MSCRATCH, CSR_RS, 32'h0000_00FF, 1, v, ill);
    `CHECK(v == 32'hA5A5_5A5A, "csrrs returns old value")
    rd(CSR_MSCRATCH, 32'hA5A5_5AFF, "mscratch after set");
    csr(CSR_MSCRATCH, CSR_RC, 32'hFFFF_0000, 1, v, ill);
    rd(CSR_MSCRATCH, 32'h0000_5AFF, "mscratch after clear");
    csr(CSR_MSCRATCH, CSR_RS, 32'hFFFF_FFFF, 0, v, ill);  // rs1 = x0: no write
    rd(CSR_MSCRATCH, 32'h0000_5AFF, "csrrs x0 does not write");
    wr_rd(CSR_MTVEC, 32'h8000_0103, 32'h8000_0101, "mtvec mode 3 -> 1 (bit1 WARL 0)");
    wr_rd(CSR_MTVEC, 32'h8000_0202, 32'h8000_0200, "mtvec mode 2 -> 0");
    wr_rd(CSR_MEPC, 32'h8000_0007, 32'h8000_0006, "mepc bit0 = 0");
    `CHECK(mepc_nc == 32'h8000_0004, "mepc without C: bits 1:0 = 0")
    wr_rd(CSR_MCAUSE, 32'h8000_000B, 32'h8000_000B, "mcause");
    wr_rd(CSR_MTVAL, 32'hFFFF_FFFF, 32'hFFFF_FFFF, "mtval");
    wr_rd(CSR_MIE, 32'hFFFF_FFFF, 32'h0000_0888, "mie only MEIE/MTIE/MSIE");
    wr_rd(CSR_MSTATUS, 32'hFFFF_FFFF, 32'h0000_1888, "mstatus only MIE/MPIE, MPP=11");
    wr_rd(CSR_MSTATUS, 32'h0, 32'h0000_1800, "mstatus clear");
    wr_rd(CSR_MISA, 32'h0, 32'h4000_1104, "misa write ignored");
    wr_rd(CSR_MHPMEVENT3, 32'h5, 32'h0, "mhpmevent3 RO-zero");
    irq_meip = 1; irq_msip = 1;
    wr_rd(CSR_MIP, 32'h0, 32'h0000_0808, "mip reflects inputs, write ignored");
    irq_meip = 0; irq_msip = 0;

    // ---------------- illegal accesses ----------------
    expect_illegal(CSR_CYCLE, 1, "write cycle");
    expect_illegal(CSR_INSTRETH, 1, "write instreth");
    expect_illegal(CSR_MVENDORID, 1, "write mvendorid");
    expect_illegal(CSR_MHARTID, 1, "write mhartid");
    csr(CSR_CYCLE, CSR_RS, 0, 0, v, ill);  `CHECK(!ill, "csrrs x0 of cycle is legal")
    expect_illegal(12'h180, 0, "satp");
    expect_illegal(12'h3A0, 0, "pmpcfg0");
    expect_illegal(12'h7A0, 0, "tselect");
    expect_illegal(12'h7B0, 0, "dcsr");
    expect_illegal(12'h100, 0, "sstatus");
    expect_illegal(12'hB1F, 0, "mhpmcounter31");
    expect_illegal(12'hC03, 0, "hpmcounter3");
    expect_illegal(12'hFFF, 0, "0xFFF");

    // ---------------- trap entry / mret ----------------
    wr_rd(CSR_MTVEC, 32'h8000_1000, 32'h8000_1000, "mtvec direct");
    wr_rd(CSR_MSTATUS, 32'h8, 32'h1808, "MIE=1");
    do_trap(0, EXC_ILLEGAL, 32'h8000_0124, 32'h0000_0073, t);
    `CHECK(t == 32'h8000_1000, "direct target")
    rd(CSR_MEPC, 32'h8000_0124, "mepc after trap");
    rd(CSR_MCAUSE, 32'h2, "mcause after trap");
    rd(CSR_MTVAL, 32'h73, "mtval after trap");
    rd(CSR_MSTATUS, 32'h1880, "MPIE=1 MIE=0 after trap");
    @(negedge clk); mret = 1; @(negedge clk); mret = 0;
    rd(CSR_MSTATUS, 32'h1888, "MIE=MPIE, MPIE=1 after mret");
    `CHECK(mepc == 32'h8000_0124, "mepc output")
    // vectored
    wr_rd(CSR_MTVEC, 32'h8000_2001, 32'h8000_2001, "mtvec vectored");
    do_trap(1, IRQ_MTI, 32'h8000_0200, 0, t);
    `CHECK(t == 32'h8000_201C, $sformatf("vectored MTI target %08x", t))
    rd(CSR_MCAUSE, 32'h8000_0007, "mcause MTI");
    do_trap(1, IRQ_MEI, 32'h8000_0200, 0, t);
    `CHECK(t == 32'h8000_202C, "vectored MEI target")
    do_trap(0, EXC_ECALL_M, 32'h8000_0200, 0, t);
    `CHECK(t == 32'h8000_2000, "vectored mode: exceptions use BASE")

    // ---------------- interrupts ----------------
    wr_rd(CSR_MIE, 32'h888, 32'h888, "mie all");
    for (int m = 0; m < 2; m++) begin
      wr_rd(CSR_MSTATUS, m ? 32'h8 : 32'h0, m ? 32'h1808 : 32'h1800, "mstatus.MIE");
      for (int p = 0; p < 8; p++) begin
        {irq_meip, irq_msip, irq_mtip} = 3'(p);
        #1;
        `CHECK(irq_req == (m && p != 0), $sformatf("irq_req MIE=%0d pend=%0d", m, p))
        if (p != 0)
          `CHECK(irq_cause == (irq_meip ? IRQ_MEI : irq_msip ? IRQ_MSI : IRQ_MTI),
                 $sformatf("priority pend=%0d cause=%0d", p, irq_cause))
      end
    end
    wr_rd(CSR_MIE, 32'h080, 32'h080, "mie MTIE only");
    {irq_meip, irq_msip, irq_mtip} = 3'b110;
    #1; `CHECK(!irq_req, "masked by mie")
    {irq_meip, irq_msip, irq_mtip} = 0;

    // ---------------- counters ----------------
    csr(CSR_MCYCLE, CSR_RS, 0, 0, v, ill);
    repeat (10) @(negedge clk);
    csr(CSR_MCYCLE, CSR_RS, 0, 0, t, ill);
    `CHECK(t - v == 12, $sformatf("mcycle delta %0d (12 edges between the reads)", t - v))
    wr_rd(CSR_MCYCLEH, 32'h1, 32'h1, "mcycleh write");
    wr_rd(CSR_MCOUNTINHIBIT, 32'hFFFF_FFFF, 32'h5, "mcountinhibit CY/IR only");
    csr(CSR_MCYCLE, CSR_RS, 0, 0, v, ill);
    repeat (5) @(negedge clk);
    rd(CSR_MCYCLE, v, "mcycle inhibited");
    wr_rd(CSR_MCOUNTINHIBIT, 0, 0, "mcountinhibit clear");
    wr_rd(CSR_MINSTRET, 32'h10, 32'h10, "minstret write");
    // retire 5 instructions
    @(negedge clk); instret_inc = 1; repeat (5) @(negedge clk); instret_inc = 0;
    rd(CSR_MINSTRET, 32'h15, "minstret after 5 retires");
    // read bypass: an instruction retires in WB while the CSR read is at MEM
    @(negedge clk);
    instret_rd_bypass = 1; instret_inc = 1;
    csr_access = 1; csr_addr = CSR_INSTRET; csr_op = CSR_RS; csr_wr = 0; csr_commit = 1;
    #1;
    `CHECK(csr_rdata == 32'h16, $sformatf("instret read includes retiring instruction: %08x", csr_rdata))
    @(negedge clk);
    idle(); instret_rd_bypass = 0; instret_inc = 0;
    rd(CSR_MINSTRET, 32'h16, "minstret after the bypassed retire");
    // write precedence over the increment of the same cycle
    @(negedge clk);
    instret_inc = 1; csr_access = 1; csr_addr = CSR_MINSTRET; csr_op = CSR_RW; csr_wr = 1;
    csr_operand = 32'hFFFF_FFFF; csr_commit = 1; instret_rd_bypass = 1;
    @(negedge clk);
    idle(); instret_inc = 0; instret_rd_bypass = 0;
    rd(CSR_MINSTRET, 32'hFFFF_FFFF, "write wins over increment");
    rd(CSR_MINSTRETH, 32'h0, "minstreth");
    @(negedge clk); instret_inc = 1; @(negedge clk); instret_inc = 0;
    rd(CSR_MINSTRETH, 32'h1, "minstret carry into high half");
    // hpm counters
    @(negedge clk); hpm_inc = 8'b1010_0101; repeat (3) @(negedge clk); hpm_inc = 0;
    rd(CSR_MHPMCOUNTER3, 3, "mhpmcounter3");
    rd(CSR_MHPMCOUNTER3 + 1, 0, "mhpmcounter4");
    rd(CSR_MHPMCOUNTER3 + 2, 3, "mhpmcounter5");
    rd(CSR_MHPMCOUNTER10, 3, "mhpmcounter10");
    rd(CSR_MHPMCOUNTER3H, 0, "mhpmcounter3h");
    wr_rd(CSR_MHPMCOUNTER3, 32'h77, 32'h3, "mhpmcounter write ignored");

    `TB_FINISH
  end
endmodule
