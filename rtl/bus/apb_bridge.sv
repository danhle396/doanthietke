// ============================================================================
// apb_bridge.sv - Data bus -> AMBA APB4 bridge (single master, 16 slots).
//   FSM: IDLE -> SETUP (PSEL=1, PENABLE=0) -> ACCESS (PENABLE=1, wait PREADY)
//   PADDR/PWRITE/PWDATA/PSTRB are latched when entering SETUP (PSTRB = 0 for
//   reads). Slot = PADDR[15:12]. A slot without a slave (SLOT_MASK bit = 0)
//   gets no PSEL; the bridge answers PREADY = 1, PSLVERR = 1 itself.
//
// Ports:
//   s_*      : request side (from dbus_xbar), response in ACCESS when ready
//   paddr..pprot, psel[15:0], penable : APB4 master signals
//   prdata/pready/pslverr : response of the selected slave (muxed outside)
// Parameters:
//   SLOT_MASK : bit i = 1 if slot i has a slave
// ============================================================================
module apb_bridge #(
  parameter logic [15:0] SLOT_MASK = 16'h801F
) (
  input  logic        clk,
  input  logic        rst_n,
  // request side
  input  logic        s_req,
  input  logic        s_we,
  input  logic [3:0]  s_be,
  input  logic [31:0] s_addr,
  input  logic [31:0] s_wdata,
  output logic        s_ready,
  output logic        s_err,
  output logic [31:0] s_rdata,
  // APB4 master
  output logic [31:0] paddr,
  output logic [15:0] psel,
  output logic        penable,
  output logic        pwrite,
  output logic [31:0] pwdata,
  output logic [3:0]  pstrb,
  output logic [2:0]  pprot,
  input  logic [31:0] prdata,
  input  logic        pready,
  input  logic        pslverr,
  output logic [3:0]  slot
);

  typedef enum logic [1:0] {S_IDLE, S_SETUP, S_ACCESS} state_e;
  state_e state_q;

  logic populated;

  assign slot      = paddr[15:12];
  assign populated = SLOT_MASK[slot];
  assign pprot     = 3'b000;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= S_IDLE;
      paddr   <= 32'b0;
      pwrite  <= 1'b0;
      pwdata  <= 32'b0;
      pstrb   <= 4'b0;
    end else begin
      case (state_q)
        S_IDLE: begin
          if (s_req) begin
            state_q <= S_SETUP;
            paddr   <= s_addr;
            pwrite  <= s_we;
            pwdata  <= s_wdata;
            pstrb   <= s_we ? s_be : 4'b0000;
          end
        end
        S_SETUP: state_q <= S_ACCESS;
        default: begin  // S_ACCESS
          if (!populated || pready) state_q <= S_IDLE;
        end
      endcase
    end
  end

  always_comb begin
    psel = 16'b0;
    if ((state_q != S_IDLE) && populated) psel[slot] = 1'b1;
  end
  assign penable = (state_q == S_ACCESS);

  assign s_ready = (state_q == S_ACCESS) && (!populated || pready);
  assign s_err   = !populated || pslverr;
  assign s_rdata = populated ? prdata : 32'b0;

endmodule
