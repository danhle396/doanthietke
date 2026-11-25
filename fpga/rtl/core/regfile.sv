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

  // packed view of the 31 registers (entry 0 = constant 0)
  logic [31:0][31:0] regs;

  assign regs[0] = 32'b0;
  genvar i;
  generate
  for (i = 1; i < 32; i = i + 1) begin : g_r
    logic [31:0] r_q;
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)                       r_q <= 32'b0;
      else if (we && waddr == 5'(i))    r_q <= wdata;
    end
    assign regs[i] = r_q;
  end
  endgenerate

  always_comb begin
    if (raddr1 == 5'd0)                  rdata1 = 32'b0;
    else if (WRITE_THROUGH && we && (waddr == raddr1)) rdata1 = wdata;
    else                                 rdata1 = regs[raddr1];
    if (raddr2 == 5'd0)                  rdata2 = 32'b0;
    else if (WRITE_THROUGH && we && (waddr == raddr2)) rdata2 = wdata;
    else                                 rdata2 = regs[raddr2];
  end

endmodule
