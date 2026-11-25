module sim_ctrl #(
  parameter int EXIT_DELAY = 1000
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [11:0] paddr,
  input  logic [31:0] pwdata,
  input  logic [3:0]  pstrb,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr
);

  logic        valid_off;
  logic        wr;
  logic        exit_req_q;
  logic [31:0] exit_code_q;
  logic [7:0]  last_char_q;

  assign valid_off = (paddr == 12'h000) || (paddr == 12'h004);
  assign wr        = psel && penable && pwrite && valid_off;
  assign prdata    = 32'b0;
  assign pready    = 1'b1;
  assign pslverr   = psel && penable && !valid_off;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      exit_req_q  <= 1'b0;
      exit_code_q <= 32'b0;
      last_char_q <= 8'b0;
    end else if (wr) begin
      if (paddr == 12'h000 && pstrb[0]) last_char_q <= pwdata[7:0];
      if (paddr == 12'h004) begin
        exit_req_q  <= 1'b1;
        exit_code_q <= pwdata;
      end
    end
  end

`ifndef SYNTHESIS
  integer console_fd = 0;
  string  console_file;
  int     exit_cnt;

  initial begin
    exit_cnt = 0;
    if ($value$plusargs("console=%s", console_file))
      console_fd = $fopen(console_file, "w");
  end

  always_ff @(posedge clk) begin
    if (wr && paddr == 12'h000 && pstrb[0]) begin
      $write("%c", pwdata[7:0]);
      if (console_fd != 0) begin
        $fwrite(console_fd, "%c", pwdata[7:0]);
        $fflush(console_fd);
      end
    end
    if (exit_req_q) begin
      exit_cnt <= exit_cnt + 1;
      if (exit_cnt == EXIT_DELAY) begin
        if (exit_code_q == 32'b0) begin
          $display("PASS");
          $finish;
        end else begin
          $display("FAIL: exit code %0d", exit_code_q);
          $fatal(1, "sim_ctrl exit code %0d", exit_code_q);
        end
      end
    end
  end
`endif

  /* verilator lint_off UNUSEDSIGNAL */
  // Dummy registers / unused strobe bits in synthesis.
  logic unused;
  assign unused = ^{last_char_q, pstrb[3:1]};
  /* verilator lint_on UNUSEDSIGNAL */

endmodule
