// ============================================================================
// intc_apb.sv - Interrupt controller (APB slave, 0x1000_4000).
//   0x00 PENDING (RO) : raw level of the sources (bit 0 UART, 1 SPI, 2 GPIO)
//   0x04 ENABLE  (RW) : reset 0
//   0x08 ACTIVE  (RO) : PENDING & ENABLE
//   irq (-> core meip) = |(PENDING & ENABLE)
//
// Ports: APB4 slave (paddr[11:0]), src[N_SRC-1:0] level inputs, irq output.
// Parameters: N_SRC (number of sources, <= 32)
// ============================================================================
module intc_apb #(
  parameter int N_SRC = 3
) (
  input  logic             clk,
  input  logic             rst_n,
  input  logic             psel,
  input  logic             penable,
  input  logic             pwrite,
  input  logic [11:0]      paddr,
  input  logic [31:0]      pwdata,
  input  logic [3:0]       pstrb,
  output logic [31:0]      prdata,
  output logic             pready,
  output logic             pslverr,
  input  logic [N_SRC-1:0] src,
  output logic             irq
);

  logic [N_SRC-1:0] enable_q;
  logic             valid_off;

  assign valid_off = (paddr == 12'h000) || (paddr == 12'h004) || (paddr == 12'h008);
  assign pready    = 1'b1;
  assign pslverr   = psel && penable && !valid_off;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      enable_q <= '0;
    end else if (psel && penable && pwrite && paddr == 12'h004) begin
      for (int i = 0; i < N_SRC; i++)
        if (pstrb[i / 8]) enable_q[i] <= pwdata[i];
    end
  end

  always_comb begin
    case (paddr)
      12'h000: prdata = 32'(src);
      12'h004: prdata = 32'(enable_q);
      12'h008: prdata = 32'(src & enable_q);
      default: prdata = 32'b0;
    endcase
  end

  assign irq = |(src & enable_q);

endmodule
