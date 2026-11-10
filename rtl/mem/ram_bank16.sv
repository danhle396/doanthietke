// ============================================================================
// ram_bank16.sv - 16-bit true dual-port RAM bank, clocked on the FALLING edge
//   (behavioural model for simulation / Yosys; the FPGA build replaces this
//   file with an altsyncram (M4K) wrapper of the same name and ports).
//   Port A: read/write with byte enables (data side).
//   Port B: read only (instruction side).
//   Address and write data are sampled at negedge clk; read data is valid
//   from that edge until the next falling edge, i.e. before the next rising
//   edge where the pipeline samples it. A read at the address being written
//   returns the old data on both ports.
//   Simulation: preloaded from +hex=<file> (32-bit words); the bank keeps
//   halfword HALF of every word.
//
// Parameters:
//   DEPTH : number of 16-bit entries (= number of 32-bit RAM words)
//   HALF  : 0 = bits [15:0] of each word, 1 = bits [31:16]
// ============================================================================
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
