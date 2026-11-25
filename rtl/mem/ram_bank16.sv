module ram_bank16 #(
  parameter int DEPTH = 32768,
  parameter int HALF  = 0
) (
  input  logic                     clk,
  // port A (data)
  input  logic [$clog2(DEPTH)-1:0] a_addr,
  input  logic                     a_we,
  input  logic [1:0]               a_be,
  input  logic [15:0]              a_wdata,
  output logic [15:0]              a_rdata,
  // port B (instruction, read only)
  input  logic [$clog2(DEPTH)-1:0] b_addr,
  output logic [15:0]              b_rdata
);

  logic [15:0] mem [DEPTH];

  always_ff @(negedge clk) begin
    if (a_we) begin
      if (a_be[0]) mem[a_addr][7:0]  <= a_wdata[7:0];
      if (a_be[1]) mem[a_addr][15:8] <= a_wdata[15:8];
    end
    a_rdata <= mem[a_addr];
    b_rdata <= mem[b_addr];
  end

`ifndef SYNTHESIS
  string       hex_file;
  logic [31:0] words [DEPTH];
  initial begin
    for (int i = 0; i < DEPTH; i++) words[i] = 32'b0;
    if ($value$plusargs("hex=%s", hex_file)) $readmemh(hex_file, words);
    for (int i = 0; i < DEPTH; i++) mem[i] = words[i][HALF*16 +: 16];
  end
`endif

endmodule
