// ============================================================================
// apb_bridge.sv - Wishbone B4 (classic) slave -> AMBA APB4 bridge
//   (single master, 16 slots).
//   FSM: IDLE -> SETUP (PSEL=1, PENABLE=0) -> ACCESS (PENABLE=1, wait PREADY)
//   A Wishbone cycle (CYC & STB) seen in IDLE latches ADR/WE/DAT/SEL into
//   PADDR/PWRITE/PWDATA/PSTRB (PSTRB = 0 for reads). The cycle is terminated
//   in ACCESS when PREADY = 1: ACK, or ERR if PSLVERR = 1. Slot = PADDR[15:12].
//   A slot without a slave (SLOT_MASK bit = 0) gets no PSEL; the bridge
//   terminates the cycle with ERR itself. Minimum 3 cycles per access.
//
// Ports:
//   wb_*     : Wishbone slave (from dbus_xbar)
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
  // Wishbone slave
  input  logic        wb_cyc_i,
  input  logic        wb_stb_i,
  input  logic        wb_we_i,
  input  logic [3:0]  wb_sel_i,
  input  logic [31:0] wb_adr_i,
  input  logic [31:0] wb_dat_i,
  output logic [31:0] wb_dat_o,
  output logic        wb_ack_o,
  output logic        wb_err_o,
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

  logic populated, done, fail;

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
          if (wb_cyc_i && wb_stb_i) begin
            state_q <= S_SETUP;
            paddr   <= wb_adr_i;
            pwrite  <= wb_we_i;
            pwdata  <= wb_dat_i;
            pstrb   <= wb_we_i ? wb_sel_i : 4'b0000;
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

  assign done     = (state_q == S_ACCESS) && (!populated || pready);
  assign fail     = !populated || pslverr;
  assign wb_ack_o = done && !fail;
  assign wb_err_o = done && fail;
  assign wb_dat_o = populated ? prdata : 32'b0;

endmodule
