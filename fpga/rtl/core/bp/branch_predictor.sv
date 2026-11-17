// ============================================================================
// branch_predictor.sv - BHT/BTB wrapper selected by BP_MODE.
//   BP_MODE 0 : static not-taken (no tables)
//   BP_MODE 1 : BHT looked up at ID with id_pc (JAL redirect done in ID)
//   BP_MODE 2 : BHT + BTB looked up at IF with if_pc
//
// Ports:
//   if_pc  -> if_pred_taken, if_pred_target, if_btb_hit (mode 2)
//   id_pc  -> id_bht_taken                               (mode 1)
//   upd_*  : updates from EX (only for valid, non-flushed instructions)
//     upd_bht     : conditional branch resolved, outcome upd_taken
//     upd_btb_wr  : taken control transfer, allocate {upd_target, upd_type}
//     upd_btb_inv : BTB predicted a non-CTI as taken (alias) -> invalidate
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module branch_predictor
#(
  parameter int BP_MODE     = 2,
  parameter int BHT_ENTRIES = 256,
  parameter int BTB_ENTRIES = 32
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] if_pc,
  output logic        if_pred_taken,
  output logic [31:0] if_pred_target,
  output logic        if_btb_hit,
  input  logic [31:0] id_pc,
  output logic        id_bht_taken,
  input  logic [31:0] upd_pc,
  input  logic        upd_bht,
  input  logic        upd_taken,
  input  logic        upd_btb_wr,
  input  logic [31:0] upd_target,
  input  logic [1:0]  upd_type,
  input  logic        upd_btb_inv
);

  generate
  if (BP_MODE == 0) begin : g_static
    assign if_pred_taken  = 1'b0;
    assign if_pred_target = 32'b0;
    assign if_btb_hit     = 1'b0;
    assign id_bht_taken   = 1'b0;
    /* verilator lint_off UNUSEDSIGNAL */
    // Static not-taken: update interface intentionally unused.
    logic unused_s;
    assign unused_s = ^{clk, rst_n, if_pc, id_pc, upd_pc, upd_bht, upd_taken, upd_btb_wr,
                      upd_target, upd_type, upd_btb_inv};
    /* verilator lint_on UNUSEDSIGNAL */
  end else if (BP_MODE == 1) begin : g_bht_id
    bht #(.ENTRIES(BHT_ENTRIES)) u_bht (
      .clk, .rst_n,
      .rd_pc    (id_pc),
      .rd_taken (id_bht_taken),
      .upd_en   (upd_bht),
      .upd_pc   (upd_pc),
      .upd_taken(upd_taken)
    );
    assign if_pred_taken  = 1'b0;
    assign if_pred_target = 32'b0;
    assign if_btb_hit     = 1'b0;
    /* verilator lint_off UNUSEDSIGNAL */
    // No BTB in mode 1.
    logic unused_b;
    assign unused_b = ^{if_pc, upd_btb_wr, upd_target, upd_type, upd_btb_inv};
    /* verilator lint_on UNUSEDSIGNAL */
  end else begin : g_btb_if
    logic       bht_taken;
    logic       hit;
    logic [1:0] btype;
    bht #(.ENTRIES(BHT_ENTRIES)) u_bht (
      .clk, .rst_n,
      .rd_pc    (if_pc),
      .rd_taken (bht_taken),
      .upd_en   (upd_bht),
      .upd_pc   (upd_pc),
      .upd_taken(upd_taken)
    );
    btb #(.ENTRIES(BTB_ENTRIES)) u_btb (
      .clk, .rst_n,
      .rd_pc    (if_pc),
      .rd_hit   (hit),
      .rd_target(if_pred_target),
      .rd_type  (btype),
      .wr_en    (upd_btb_wr),
      .wr_pc    (upd_pc),
      .wr_target(upd_target),
      .wr_type  (upd_type),
      .inv_en   (upd_btb_inv),
      .inv_pc   (upd_pc)
    );
    assign if_btb_hit    = hit;
    assign if_pred_taken = hit && ((btype != BT_BRANCH) || bht_taken);
    assign id_bht_taken  = 1'b0;
    /* verilator lint_off UNUSEDSIGNAL */
    // ID lookup only used in mode 1.
    logic unused_i;
    assign unused_i = ^id_pc;
    /* verilator lint_on UNUSEDSIGNAL */
  end
  endgenerate

endmodule
