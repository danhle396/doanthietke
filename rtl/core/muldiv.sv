// ============================================================================
// muldiv.sv - RV32M unit.
//   MUL/MULH/MULHSU/MULHU : single-cycle 33x33 signed combinational multiplier
//   DIV/DIVU/REM/REMU     : radix-2 restoring divider, 32 iterations
//                           (operands latched at start); divide-by-zero and
//                           signed overflow return immediately.
//
// Ports:
//   valid   : EX holds a valid M instruction (no pending exception)
//   op      : funct3 (rv_pkg MD_*)
//   a, b    : rs1, rs2 values
//   kill    : pipeline flush -> abort divider
//   advance : EX stage hands its result to MEM this cycle (releases DONE)
//   ready   : result valid in this cycle
//   result  : 32-bit result
//   busy    : divider is iterating
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module muldiv
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        valid,
  input  logic [2:0]  op,
  input  logic [31:0] a,
  input  logic [31:0] b,
  input  logic        kill,
  input  logic        advance,
  output logic        ready,
  output logic [31:0] result,
  output logic        busy
);

  // ---------------- Multiplier ----------------
  logic               a_sign, b_sign;
  logic signed [32:0] a_ext, b_ext;
  /* verilator lint_off UNUSEDSIGNAL */
  logic signed [65:0] prod;  // 33x33 product, bits [65:64] are sign extension
  /* verilator lint_on UNUSEDSIGNAL */
  logic [31:0]        mul_res;

  assign a_sign = (op == MD_MULH) || (op == MD_MULHSU);
  assign b_sign = (op == MD_MULH);
  assign a_ext  = {a_sign & a[31], a};
  assign b_ext  = {b_sign & b[31], b};
  // Plain signed operands and a 66-bit signed target: the product is sized by
  // the assignment context (IEEE 1364 rule) in every tool. A size cast of the
  // product, 66'(x * y), is read by Quartus II 13.0 as a 33-bit product that is
  // then sign-extended (MULH/MULHU returned only copies of bit 32 on the board).
  assign prod   = a_ext * b_ext;
  assign mul_res = (op == MD_MUL) ? prod[31:0] : prod[63:32];

  // ---------------- Divider ----------------
  typedef enum logic [1:0] {D_IDLE, D_BUSY, D_DONE} dstate_e;
  dstate_e     state_q;
  logic [5:0]  cnt_q;
  logic [31:0] quo_q, rem_q, dvs_q;
  logic        neg_q_q, neg_r_q, is_rem_q;

  logic        is_div, is_signed_div, is_rem_op;
  logic        div_by_zero, overflow, special;
  logic [31:0] special_res;
  logic [32:0] shifted, diff;
  logic [31:0] q_fix, r_fix;

  assign is_div        = op[2];
  assign is_signed_div = !op[0];
  assign is_rem_op     = op[1];
  assign div_by_zero   = (b == 32'b0);
  assign overflow      = is_signed_div && (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);
  assign special       = div_by_zero || overflow;

  always_comb begin
    if (div_by_zero) special_res = is_rem_op ? a : 32'hFFFF_FFFF;
    else             special_res = is_rem_op ? 32'b0 : 32'h8000_0000;  // overflow
  end

  assign shifted = {rem_q, quo_q[31]};
  assign diff    = shifted - {1'b0, dvs_q};
  assign q_fix   = neg_q_q ? (~quo_q + 32'd1) : quo_q;
  assign r_fix   = neg_r_q ? (~rem_q + 32'd1) : rem_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q  <= D_IDLE;
      cnt_q    <= 6'd0;
      quo_q    <= 32'b0;
      rem_q    <= 32'b0;
      dvs_q    <= 32'b0;
      neg_q_q  <= 1'b0;
      neg_r_q  <= 1'b0;
      is_rem_q <= 1'b0;
    end else if (kill) begin
      state_q <= D_IDLE;
    end else begin
      case (state_q)
        D_IDLE: begin
          if (valid && is_div && !special) begin
            state_q  <= D_BUSY;
            cnt_q    <= 6'd32;
            rem_q    <= 32'b0;
            quo_q    <= (is_signed_div && a[31]) ? (~a + 32'd1) : a;
            dvs_q    <= (is_signed_div && b[31]) ? (~b + 32'd1) : b;
            neg_q_q  <= is_signed_div && (a[31] ^ b[31]);
            neg_r_q  <= is_signed_div && a[31];
            is_rem_q <= is_rem_op;
          end
        end
        D_BUSY: begin
          if (!diff[32]) begin
            rem_q <= diff[31:0];
            quo_q <= {quo_q[30:0], 1'b1};
          end else begin
            rem_q <= shifted[31:0];
            quo_q <= {quo_q[30:0], 1'b0};
          end
          cnt_q <= cnt_q - 6'd1;
          if (cnt_q == 6'd1) state_q <= D_DONE;
        end
        default: begin  // D_DONE
          if (advance) state_q <= D_IDLE;
        end
      endcase
    end
  end

  // ---------------- Output ----------------
  always_comb begin
    if (!is_div) begin
      ready  = valid;
      result = mul_res;
    end else if (state_q == D_DONE) begin
      ready  = valid;
      result = is_rem_q ? r_fix : q_fix;
    end else if (state_q == D_IDLE && special) begin
      ready  = valid;
      result = special_res;
    end else begin
      ready  = 1'b0;
      result = 32'b0;
    end
  end

  assign busy = (state_q == D_BUSY);

endmodule
