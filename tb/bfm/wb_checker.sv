// ============================================================================
// wb_checker.sv - Wishbone B4 classic protocol checker (passive monitor).
//   Sampled at every rising clock edge:
//     - CYC and STB negated while reset is asserted (B4 rule 3.20)
//     - STB only together with CYC
//     - ACK and ERR never together, and only during CYC & STB
//     - a request that was not terminated (no ACK/ERR) stays asserted with
//       the same ADR, WE, SEL and (for writes) DAT in the next cycle; the SoC
//       masters never abort a cycle, so withdrawing it is reported as well
//   Counts terminated transfers, error terminations and wait cycles.
//
// Ports: the master-side view of one Wishbone link (dat_w = master DAT_O).
// Parameters:
//   NAME : label used in messages
// ============================================================================
`timescale 1ns/1ps

module wb_checker #(
  parameter string NAME = "wb"
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        cyc,
  input  logic        stb,
  input  logic        we,
  input  logic [3:0]  sel,
  input  logic [31:0] adr,
  input  logic [31:0] dat_w,
  input  logic        ack,
  input  logic        err
);

  int unsigned violations  = 0;
  int unsigned transfers   = 0;
  int unsigned errors      = 0;
  int unsigned wait_cycles = 0;

  logic        pend_q = 1'b0;
  logic        we_q;
  logic [3:0]  sel_q;
  logic [31:0] adr_q, dat_q;

  task automatic violation(input string msg);
    violations++;
    if (violations <= 5) $display("[wb] %s: VIOLATION at %0t: %s", NAME, $time, msg);
  endtask

  always @(posedge clk) begin
    if (!rst_n) begin
      if (cyc || stb) violation("CYC/STB asserted during reset");
      pend_q <= 1'b0;
    end else begin
      if (stb && !cyc)                    violation("STB without CYC");
      if (ack && err)                     violation("ACK and ERR together");
      if ((ack || err) && !(cyc && stb))  violation("ACK/ERR without CYC & STB");
      if (pend_q) begin
        if (!(cyc && stb))
          violation("request withdrawn before ACK/ERR");
        else if (adr != adr_q || we != we_q || sel != sel_q || (we && dat_w != dat_q))
          violation("ADR/WE/SEL/DAT changed while waiting for ACK/ERR");
      end
      if (cyc && stb) begin
        if (ack)              transfers++;
        if (err)              errors++;
        if (!ack && !err)     wait_cycles++;
      end
      pend_q <= cyc && stb && !ack && !err;
      adr_q  <= adr;
      we_q   <= we;
      sel_q  <= sel;
      dat_q  <= dat_w;
    end
  end

endmodule
