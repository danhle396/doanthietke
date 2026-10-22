// ============================================================================
// rst_sync.sv - Reset synchronizer: asynchronous assert, synchronous
//   de-assert through a 2-flip-flop chain.
//
// Ports:
//   rst_n_in  : external asynchronous active-low reset
//   rst_n_out : synchronized active-low reset for the SoC
// ============================================================================
module rst_sync (
  input  logic clk,
  input  logic rst_n_in,
  output logic rst_n_out
);

  logic [1:0] sync_q;

  always_ff @(posedge clk or negedge rst_n_in) begin
    if (!rst_n_in) sync_q <= 2'b00;
    else           sync_q <= {sync_q[0], 1'b1};
  end

  assign rst_n_out = sync_q[1];

endmodule
