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
