// ============================================================================
// gpio_apb.sv - 16-pin GPIO with edge interrupts (APB slave, 0x1000_3000).
//   0x00 OUT (RW), 0x04 IN (RO, 2-FF synchronized), 0x08 DIR (RW, 1 = output),
//   0x0C IRQ_EN (RW), 0x10 IRQ_STATUS (R/W1C, sticky edge flags),
//   0x14 IRQ_TYPE (RW, 0 = rising, 1 = falling)
//   Edge detection starts two clocks after reset (synchronizer filled), so a
//   pin that is already high at reset does not produce a rising edge.
//   irq = |(IRQ_STATUS & IRQ_EN). A new edge wins over W1C in the same cycle.
//
// Ports: APB4 slave (paddr[11:0]), gpio_i/gpio_o/gpio_oe, irq.
// Parameters: N (number of pins, <= 16)
// ============================================================================
module gpio_apb #(
  parameter int N = 16
) (
  input  logic         clk,
  input  logic         rst_n,
  input  logic         psel,
  input  logic         penable,
  input  logic         pwrite,
  input  logic [11:0]  paddr,
  input  logic [31:0]  pwdata,
  input  logic [3:0]   pstrb,
  output logic [31:0]  prdata,
  output logic         pready,
  output logic         pslverr,
  input  logic [N-1:0] gpio_i,
  output logic [N-1:0] gpio_o,
  output logic [N-1:0] gpio_oe,
  output logic         irq
);

  localparam logic [11:0] A_OUT = 12'h00, A_IN = 12'h04, A_DIR = 12'h08, A_IRQ_EN = 12'h0C,
                          A_IRQ_ST = 12'h10, A_IRQ_TYPE = 12'h14;

  logic valid_off, wr;
  assign valid_off = (paddr == A_OUT) || (paddr == A_IN) || (paddr == A_DIR) ||
                     (paddr == A_IRQ_EN) || (paddr == A_IRQ_ST) || (paddr == A_IRQ_TYPE);
  assign wr      = psel && penable && pwrite && valid_off;
  assign pready  = 1'b1;
  assign pslverr = psel && penable && !valid_off;

  // PSTRB expanded to bits (registers are at most 16 bits wide)
  /* verilator lint_off UNUSEDSIGNAL */
  // Only the low N bits of the bus word / strobe mask are used.
  logic [31:0]  bmask32;
  logic [31:0]  pwdata_u;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [N-1:0] bm, wd;
  assign bmask32 = {{8{pstrb[3]}}, {8{pstrb[2]}}, {8{pstrb[1]}}, {8{pstrb[0]}}};
  assign bm      = bmask32[N-1:0];
  assign pwdata_u = pwdata;
  assign wd      = pwdata_u[N-1:0];

  logic [N-1:0] out_q, dir_q, en_q, type_q, st_q;
  logic [N-1:0] sync1_q, in_q, prev_q, ev, w1c;
  logic [1:0]   prime_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sync1_q <= '0;
      in_q    <= '0;
      prev_q  <= '0;
      prime_q <= 2'd0;
    end else begin
      sync1_q <= gpio_i;
      in_q    <= sync1_q;
      prev_q  <= in_q;
      if (prime_q != 2'd3) prime_q <= prime_q + 2'd1;
    end
  end

  // edge events (enabled once the synchronizer and prev_q hold real samples)
  always_comb begin
    for (int i = 0; i < N; i++)
      ev[i] = (prime_q == 2'd3) && (type_q[i] ? (prev_q[i] && !in_q[i]) : (!prev_q[i] && in_q[i]));
  end

  assign w1c = (wr && paddr == A_IRQ_ST) ? (wd & bm) : '0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_q  <= '0;
      dir_q  <= '0;
      en_q   <= '0;
      type_q <= '0;
      st_q   <= '0;
    end else begin
      if (wr && paddr == A_OUT)      out_q  <= (out_q & ~bm) | (wd & bm);
      if (wr && paddr == A_DIR)      dir_q  <= (dir_q & ~bm) | (wd & bm);
      if (wr && paddr == A_IRQ_EN)   en_q   <= (en_q & ~bm) | (wd & bm);
      if (wr && paddr == A_IRQ_TYPE) type_q <= (type_q & ~bm) | (wd & bm);
      st_q <= ev | (st_q & ~w1c);
    end
  end

  assign gpio_o  = out_q;
  assign gpio_oe = dir_q;
  assign irq     = |(st_q & en_q);

  always_comb begin
    case (paddr)
      A_OUT:      prdata = 32'(out_q);
      A_IN:       prdata = 32'(in_q);
      A_DIR:      prdata = 32'(dir_q);
      A_IRQ_EN:   prdata = 32'(en_q);
      A_IRQ_ST:   prdata = 32'(st_q);
      A_IRQ_TYPE: prdata = 32'(type_q);
      default:    prdata = 32'b0;
    endcase
  end

endmodule
