// ============================================================================
// sync_fifo.sv - Synchronous first-word-fall-through FIFO.
//   rdata always shows the oldest entry (valid when !empty).
//   push when full is ignored unless a pop happens in the same cycle;
//   pop when empty is ignored; simultaneous push and pop are allowed.
//
// Ports: push/wdata, pop/rdata, full, empty, level (0..DEPTH)
// Parameters: WIDTH, DEPTH (power of two, >= 2)
// ============================================================================
module sync_fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 16
) (
  input  logic                   clk,
  input  logic                   rst_n,
  input  logic                   push,
  input  logic [WIDTH-1:0]       wdata,
  input  logic                   pop,
  output logic [WIDTH-1:0]       rdata,
  output logic                   full,
  output logic                   empty,
  output logic [$clog2(DEPTH):0] level
);

  localparam int AW = $clog2(DEPTH);

  logic [WIDTH-1:0] mem [DEPTH];
  logic [AW-1:0]    wptr, rptr;
  logic             do_push, do_pop;

  assign empty   = (level == '0);
  assign full    = (level == (AW+1)'(DEPTH));
  assign do_pop  = pop && !empty;
  assign do_push = push && (!full || do_pop);
  assign rdata   = mem[rptr];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wptr  <= '0;
      rptr  <= '0;
      level <= '0;
    end else begin
      if (do_push) wptr <= wptr + 1'b1;
      if (do_pop)  rptr <= rptr + 1'b1;
      case ({do_push, do_pop})
        2'b10:   level <= level + 1'b1;
        2'b01:   level <= level - 1'b1;
        default: ;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    if (do_push) mem[wptr] <= wdata;
  end

endmodule
