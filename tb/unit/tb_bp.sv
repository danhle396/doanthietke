`timescale 1ns/1ps
`include "tb_common.svh"

module tb_bp;
  import rv_pkg::*;
  `TB_DECLS

  localparam int NB = 16;  // BHT entries
  localparam int NT = 8;   // BTB entries

  logic clk = 0, rst_n = 0;
  always #5 clk = ~clk;

  // ---------------- BHT ----------------
  logic [31:0] bht_rd_pc, bht_upd_pc;
  logic        bht_taken, bht_upd_en, bht_upd_taken;
  bht #(.ENTRIES(NB)) u_bht (.clk, .rst_n, .rd_pc(bht_rd_pc), .rd_taken(bht_taken),
                             .upd_en(bht_upd_en), .upd_pc(bht_upd_pc), .upd_taken(bht_upd_taken));

  // ---------------- BTB ----------------
  logic [31:0] btb_rd_pc, btb_target, btb_wr_pc, btb_wr_target, btb_inv_pc;
  logic        btb_hit, btb_wr_en, btb_inv_en;
  logic [1:0]  btb_type, btb_wr_type;
  btb #(.ENTRIES(NT)) u_btb (.clk, .rst_n, .rd_pc(btb_rd_pc), .rd_hit(btb_hit),
                             .rd_target(btb_target), .rd_type(btb_type), .wr_en(btb_wr_en),
                             .wr_pc(btb_wr_pc), .wr_target(btb_wr_target), .wr_type(btb_wr_type),
                             .inv_en(btb_inv_en), .inv_pc(btb_inv_pc));

  // ---------------- wrappers ----------------
  logic [31:0] p_if_pc, p_id_pc, p_upd_pc, p_upd_target, p2_target, p1_target;
  logic        p_upd_bht, p_upd_taken, p_upd_wr, p_upd_inv;
  logic [1:0]  p_upd_type;
  logic        p2_taken, p2_hit, p2_id_taken, p1_taken, p1_hit, p1_id_taken;

  branch_predictor #(.BP_MODE(2), .BHT_ENTRIES(NB), .BTB_ENTRIES(NT)) u_bp2 (
    .clk, .rst_n, .if_pc(p_if_pc), .if_pred_taken(p2_taken), .if_pred_target(p2_target),
    .if_btb_hit(p2_hit), .id_pc(p_id_pc), .id_bht_taken(p2_id_taken), .upd_pc(p_upd_pc),
    .upd_bht(p_upd_bht), .upd_taken(p_upd_taken), .upd_btb_wr(p_upd_wr),
    .upd_target(p_upd_target), .upd_type(p_upd_type), .upd_btb_inv(p_upd_inv));
  branch_predictor #(.BP_MODE(1), .BHT_ENTRIES(NB), .BTB_ENTRIES(NT)) u_bp1 (
    .clk, .rst_n, .if_pc(p_if_pc), .if_pred_taken(p1_taken), .if_pred_target(p1_target),
    .if_btb_hit(p1_hit), .id_pc(p_id_pc), .id_bht_taken(p1_id_taken), .upd_pc(p_upd_pc),
    .upd_bht(p_upd_bht), .upd_taken(p_upd_taken), .upd_btb_wr(p_upd_wr),
    .upd_target(p_upd_target), .upd_type(p_upd_type), .upd_btb_inv(p_upd_inv));

  // ---------------- models ----------------
  logic [1:0]  m_cnt [NB];
  logic        m_valid [NT];
  logic [31:0] m_pc [NT], m_tgt [NT];
  logic [1:0]  m_type [NT];
  logic [1:0]  w_cnt [NB];  // model of the wrapper BHT

  function automatic int bidx(logic [31:0] pc); return int'(pc[$clog2(NB):1]); endfunction
  function automatic int tidx(logic [31:0] pc); return int'(pc[$clog2(NT):1]); endfunction

  task automatic bht_update(logic [31:0] pc, logic t);
    @(negedge clk);
    bht_upd_en = 1; bht_upd_pc = pc; bht_upd_taken = t;
    @(negedge clk);
    bht_upd_en = 0;
    if (t && m_cnt[bidx(pc)] != 3) m_cnt[bidx(pc)]++;
    if (!t && m_cnt[bidx(pc)] != 0) m_cnt[bidx(pc)]--;
  endtask

  task automatic bht_check(logic [31:0] pc);
    bht_rd_pc = pc;
    #1;
    `CHECK(bht_taken === m_cnt[bidx(pc)][1],
           $sformatf("BHT pc=%08x pred=%0d model cnt=%0d", pc, bht_taken, m_cnt[bidx(pc)]))
  endtask

  task automatic btb_write(logic [31:0] pc, logic [31:0] tgt, logic [1:0] ty);
    @(negedge clk);
    btb_wr_en = 1; btb_wr_pc = pc; btb_wr_target = tgt; btb_wr_type = ty;
    @(negedge clk);
    btb_wr_en = 0;
    m_valid[tidx(pc)] = 1; m_pc[tidx(pc)] = pc; m_tgt[tidx(pc)] = {tgt[31:1], 1'b0};
    m_type[tidx(pc)] = ty;
  endtask

  task automatic btb_inval(logic [31:0] pc);
    @(negedge clk);
    btb_inv_en = 1; btb_inv_pc = pc;
    @(negedge clk);
    btb_inv_en = 0;
    m_valid[tidx(pc)] = 0;
  endtask

  task automatic btb_check(logic [31:0] pc);
    logic hit;
    btb_rd_pc = pc;
    #1;
    hit = m_valid[tidx(pc)] && (m_pc[tidx(pc)][31:1] == pc[31:1]);
    `CHECK(btb_hit === hit, $sformatf("BTB pc=%08x hit=%0d exp %0d", pc, btb_hit, hit))
    if (hit) begin
      `CHECK(btb_target === m_tgt[tidx(pc)] && btb_type === m_type[tidx(pc)],
             $sformatf("BTB pc=%08x target %08x/%0d exp %08x/%0d", pc, btb_target, btb_type,
                       m_tgt[tidx(pc)], m_type[tidx(pc)]))
    end
  endtask

  // wrapper: one EX update, mirrored in the wrapper model
  task automatic wrap_update(logic [31:0] pc, logic is_br, logic t, logic wr, logic [31:0] tgt,
                             logic [1:0] ty, logic inv);
    @(negedge clk);
    p_upd_pc = pc; p_upd_bht = is_br; p_upd_taken = t; p_upd_wr = wr; p_upd_target = tgt;
    p_upd_type = ty; p_upd_inv = inv;
    @(negedge clk);
    p_upd_bht = 0; p_upd_wr = 0; p_upd_inv = 0;
    if (is_br) begin
      if (t && w_cnt[bidx(pc)] != 3) w_cnt[bidx(pc)]++;
      if (!t && w_cnt[bidx(pc)] != 0) w_cnt[bidx(pc)]--;
    end
  endtask

  `TB_TIMEOUT(20ms)

  initial begin
    `TB_INIT
    bht_upd_en = 0; btb_wr_en = 0; btb_inv_en = 0; p_upd_bht = 0; p_upd_wr = 0; p_upd_inv = 0;
    bht_rd_pc = 0; btb_rd_pc = 0; p_if_pc = 0; p_id_pc = 0; bht_upd_pc = 0; bht_upd_taken = 0;
    btb_wr_pc = 0; btb_wr_target = 0; btb_wr_type = 0; btb_inv_pc = 0;
    p_upd_pc = 0; p_upd_taken = 0; p_upd_target = 0; p_upd_type = 0;
    foreach (m_cnt[i]) begin m_cnt[i] = 2'b01; w_cnt[i] = 2'b01; end
    foreach (m_valid[i]) m_valid[i] = 0;
    repeat (2) @(posedge clk);
    rst_n = 1;

    // ---- BHT directed: reset value, saturation up and down ----
    for (int i = 0; i < NB; i++) bht_check(32'h8000_0000 + 32'(2 * i));
    `CHECK(bht_taken === 1'b0, "BHT must reset to weakly not-taken")
    for (int k = 0; k < 5; k++) begin bht_update(32'h8000_0010, 1); bht_check(32'h8000_0010); end
    `CHECK(m_cnt[bidx(32'h8000_0010)] == 3, "model saturates at 3")
    bht_update(32'h8000_0010, 0); bht_check(32'h8000_0010);  // 3 -> 2: still taken
    `CHECK(bht_taken === 1'b1, "strongly taken needs two not-taken to flip")
    for (int k = 0; k < 5; k++) begin bht_update(32'h8000_0010, 0); bht_check(32'h8000_0010); end
    bht_update(32'h8000_0010, 1); bht_check(32'h8000_0010);  // 0 -> 1: still not taken
    `CHECK(bht_taken === 1'b0, "strongly not-taken needs two taken to flip")
    bht_check(32'h8000_0012);  // neighbour entry unaffected
    // ---- BHT random ----
    for (int n = 0; n < 3000; n++) begin
      logic [31:0] pc;
      pc = 32'h8000_0000 + 32'($urandom_range(0, 255) * 2);
      bht_update(pc, 1'($urandom_range(0, 1)));
      bht_check(32'h8000_0000 + 32'($urandom_range(0, 255) * 2));
    end

    // ---- BTB directed: miss, hit, alias, replace, invalidate ----
    btb_check(32'h8000_0100);                                    // miss after reset
    btb_write(32'h8000_0100, 32'h8000_0200, BT_BRANCH);
    btb_check(32'h8000_0100);                                    // hit
    btb_check(32'h8000_0100 + 32'(2 * NT));                      // alias: same index, other tag -> miss
    btb_write(32'h8000_0100 + 32'(2 * NT), 32'h8000_0300, BT_JAL); // replacement
    btb_check(32'h8000_0100);                                    // old PC now misses
    btb_check(32'h8000_0100 + 32'(2 * NT));
    btb_write(32'h8000_0102, 32'h8000_0400, BT_JALR);            // halfword PC, other index
    btb_check(32'h8000_0102);
    btb_inval(32'h8000_0102);
    btb_check(32'h8000_0102);                                    // invalidated -> miss
    // ---- BTB random ----
    for (int n = 0; n < 3000; n++) begin
      logic [31:0] pc;
      pc = 32'h8000_0000 + 32'($urandom_range(0, 63) * 2);
      case ($urandom_range(0, 3))
        0, 1: btb_write(pc, $urandom & ~32'h1, 2'($urandom_range(0, 2)));
        2:    btb_inval(pc);
        default: ;
      endcase
      btb_check(32'h8000_0000 + 32'($urandom_range(0, 63) * 2));
    end

    // ---- wrapper mode 2 / mode 1 ----
    p_if_pc = 32'h8000_1000; p_id_pc = 32'h8000_1000; #1;
    `CHECK(!p2_taken && !p2_hit, "mode 2: miss after reset")
    wrap_update(32'h8000_1000, 1, 1, 1, 32'h8000_2000, BT_BRANCH, 0);  // taken branch: alloc + cnt 2
    #1;
    `CHECK(p2_hit && p2_taken && p2_target == 32'h8000_2000, "mode 2: taken branch predicted")
    `CHECK(p1_id_taken && !p1_taken && !p1_hit, "mode 1: BHT at ID only")
    wrap_update(32'h8000_1000, 1, 0, 0, 0, BT_BRANCH, 0);              // not taken: cnt 1
    #1;
    `CHECK(p2_hit && !p2_taken, "mode 2: BTB hit but BHT not-taken -> fall through")
    `CHECK(!p1_id_taken, "mode 1: BHT not taken")
    wrap_update(32'h8000_1004, 0, 1, 1, 32'h8000_3000, BT_JAL, 0);     // JAL always taken
    p_if_pc = 32'h8000_1004; #1;
    `CHECK(p2_taken && p2_target == 32'h8000_3000, "mode 2: JAL predicted from BTB")
    wrap_update(32'h8000_1004, 0, 0, 0, 0, BT_BRANCH, 1);              // alias clear
    #1;
    `CHECK(!p2_hit && !p2_taken, "mode 2: invalidated entry")
    `CHECK(!p2_id_taken, "mode 2: no ID lookup")

    `TB_FINISH
  end
endmodule
