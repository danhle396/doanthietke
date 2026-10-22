// ============================================================================
// regfile.sv - 32 x 32-bit register file, 2 read / 1 write ports.
//   x0 is hard-wired to 0. Write-through: a write in the same cycle is
//   visible on the read ports (WB -> ID bypass).
//
// Ports:
//   we, waddr, wdata : write port (synchronous)
//   raddr1/2, rdata1/2 : combinational read ports
// Parameters:
//   WRITE_THROUGH : 1 = same-cycle write visible on reads (pipeline);
//                   0 = plain read (single-cycle core, avoids a comb. loop)
// ============================================================================
module regfile #(
  parameter bit WRITE_THROUGH = 1'b1
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        we,
  input  logic [4:0]  waddr,
  input  logic [31:0] wdata,
  input  logic [4:0]  raddr1,
  input  logic [4:0]  raddr2,
  output logic [31:0] rdata1,
  output logic [31:0] rdata2
);

  logic [31:0] regs [1:31];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < 32; i++) regs[i] <= 32'b0;
    end else if (we && (waddr != 5'd0)) begin
      regs[waddr] <= wdata;
    end
  end

  always_comb begin
    if (raddr1 == 5'd0)                  rdata1 = 32'b0;
    else if (WRITE_THROUGH && we && (waddr == raddr1)) rdata1 = wdata;
    else                                 rdata1 = regs[raddr1];
    if (raddr2 == 5'd0)                  rdata2 = 32'b0;
    else if (WRITE_THROUGH && we && (waddr == raddr2)) rdata2 = wdata;
    else                                 rdata2 = regs[raddr2];
  end

endmodule
