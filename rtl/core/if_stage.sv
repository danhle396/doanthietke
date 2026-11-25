module if_stage #(
  parameter logic [31:0] RESET_PC = 32'h8000_0000,
  parameter bit          ENABLE_C = 1'b1
) (
  input  logic        clk,
  input  logic        rst_n,
  // instruction bus
  output logic [31:0] ibus_addr,
  input  logic [31:0] ibus_rdata,
  input  logic        ibus_ack,
  input  logic        ibus_err,
  // prediction
  output logic [31:0] pc,
  input  logic        bp_taken,
  input  logic [31:0] bp_target,
  // redirects
  input  logic        mem_redirect,
  input  logic [31:0] mem_target,
  input  logic        ex_redirect,
  input  logic [31:0] ex_target,
  input  logic        id_redirect,
  input  logic [31:0] id_target,
  // pipeline control
  input  logic        stall_if,
  input  logic        stall_id,
  input  logic        flush_if_id,
  // if_id register
  output logic        id_valid,
  output logic [31:0] id_pc,
  output logic [31:0] id_insn,
  output logic        id_is_c,
  output logic [31:0] id_pred_npc,
  output logic        id_fault
);

    logic [31:0] pc_q, pc_d;
  logic        is_c, fetch_ok;
  logic [31:0] seq_npc, pred_npc;

  assign pc        = pc_q;
  assign ibus_addr = pc_q;
  assign is_c      = ENABLE_C && (ibus_rdata[1:0] != 2'b11);
  assign seq_npc   = pc_q + (is_c ? 32'd2 : 32'd4);
  assign pred_npc  = bp_taken ? bp_target : seq_npc;
  assign fetch_ok  = ibus_ack || ibus_err;

  always_comb begin
    if (mem_redirect)     pc_d = mem_target;
    else if (ex_redirect) pc_d = ex_target;
    else if (id_redirect) pc_d = id_target;
    else if (stall_if || !fetch_ok) pc_d = pc_q;
    else                  pc_d = pred_npc;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pc_q <= RESET_PC;
    else        pc_q <= pc_d;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      id_valid    <= 1'b0;
      id_pc       <= 32'b0;
      id_insn     <= 32'b0;
      id_is_c     <= 1'b0;
      id_pred_npc <= 32'b0;
      id_fault    <= 1'b0;
    end else if (flush_if_id) begin
      id_valid    <= 1'b0;
    end else if (!stall_id) begin
      id_valid    <= fetch_ok;
      id_pc       <= pc_q;
      id_insn     <= ibus_rdata;
      id_is_c     <= is_c;
      id_pred_npc <= pred_npc;
      id_fault    <= ibus_err;
    end
  end

endmodule
