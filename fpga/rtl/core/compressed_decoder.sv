/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module compressed_decoder
(
  input  logic [15:0] cinsn,
  output logic [31:0] insn,
  output logic        illegal
);

  logic [2:0]  funct3;
  logic [4:0]  rd_full, rs2_full;
  logic [4:0]  rdp, rs1p, rs2p;   // x8..x15
  logic [11:0] imm6;              // sign-extended CI immediate
  logic [11:0] addi4spn_imm, lw_imm, lwsp_imm, swsp_imm, addi16sp_imm;
  logic [19:0] lui_imm;
  logic [20:0] j_imm;
  logic [12:0] b_imm;

  assign funct3   = cinsn[15:13];
  assign rd_full  = cinsn[11:7];
  assign rs2_full = cinsn[6:2];
  assign rdp      = {2'b01, cinsn[4:2]};
  assign rs1p     = {2'b01, cinsn[9:7]};
  assign rs2p     = {2'b01, cinsn[4:2]};

  assign imm6         = {{7{cinsn[12]}}, cinsn[6:2]};
  assign addi4spn_imm = {2'b0, cinsn[10:7], cinsn[12:11], cinsn[5], cinsn[6], 2'b00};
  assign lw_imm       = {5'b0, cinsn[5], cinsn[12:10], cinsn[6], 2'b00};
  assign lwsp_imm     = {4'b0, cinsn[3:2], cinsn[12], cinsn[6:4], 2'b00};
  assign swsp_imm     = {4'b0, cinsn[8:7], cinsn[12:9], 2'b00};
  assign addi16sp_imm = {{3{cinsn[12]}}, cinsn[4:3], cinsn[5], cinsn[2], cinsn[6], 4'b0};
  assign lui_imm      = {{15{cinsn[12]}}, cinsn[6:2]};
  assign j_imm        = {{10{cinsn[12]}}, cinsn[8], cinsn[10:9], cinsn[6], cinsn[7],
                         cinsn[2], cinsn[11], cinsn[5:3], 1'b0};
  assign b_imm        = {{5{cinsn[12]}}, cinsn[6:5], cinsn[2], cinsn[11:10], cinsn[4:3], 1'b0};

  // 32-bit encoders
  function automatic logic [31:0] enc_i(input logic [11:0] imm, input logic [4:0] rs1,
                                        input logic [2:0] f3, input logic [4:0] rd,
                                        input logic [6:0] opc);
    enc_i = {imm, rs1, f3, rd, opc};
  endfunction

  function automatic logic [31:0] enc_s(input logic [11:0] imm, input logic [4:0] rs2,
                                        input logic [4:0] rs1, input logic [2:0] f3);
    enc_s = {imm[11:5], rs2, rs1, f3, imm[4:0], OPC_STORE};
  endfunction

  function automatic logic [31:0] enc_r(input logic [6:0] f7, input logic [4:0] rs2,
                                        input logic [4:0] rs1, input logic [2:0] f3,
                                        input logic [4:0] rd);
    enc_r = {f7, rs2, rs1, f3, rd, OPC_OP};
  endfunction

  /* verilator lint_off UNUSEDSIGNAL */
  // imm[0] of B/J immediates is always 0 and not encoded.
  function automatic logic [31:0] enc_b(input logic [12:0] imm, input logic [4:0] rs1,
                                        input logic [2:0] f3);
    enc_b = {imm[12], imm[10:5], 5'd0, rs1, f3, imm[4:1], imm[11], OPC_BRANCH};
  endfunction

  function automatic logic [31:0] enc_j(input logic [20:0] imm, input logic [4:0] rd);
    enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, OPC_JAL};
  endfunction
  /* verilator lint_on UNUSEDSIGNAL */

  always_comb begin
    insn    = 32'h0000_0013;  // NOP
    illegal = 1'b0;
    case (cinsn[1:0])
      // ------------------------------------------------ Quadrant 0
      2'b00: begin
        case (funct3)
          3'b000: begin  // C.ADDI4SPN (nzuimm == 0 is reserved; covers all-zero insn)
            insn    = enc_i(addi4spn_imm, 5'd2, 3'b000, rdp, OPC_OP_IMM);
            illegal = (cinsn[12:5] == 8'b0);
          end
          3'b010:  insn = enc_i(lw_imm, rs1p, 3'b010, rdp, OPC_LOAD);  // C.LW
          3'b110:  insn = enc_s(lw_imm, rs2p, rs1p, 3'b010);           // C.SW
          default: illegal = 1'b1;  // C.FLD/C.FLW/C.FSD/C.FSW, reserved
        endcase
      end
      // ------------------------------------------------ Quadrant 1
      2'b01: begin
        case (funct3)
          3'b000: insn = enc_i(imm6, rd_full, 3'b000, rd_full, OPC_OP_IMM);  // C.ADDI / C.NOP
          3'b001: insn = enc_j(j_imm, 5'd1);                                 // C.JAL
          3'b010: insn = enc_i(imm6, 5'd0, 3'b000, rd_full, OPC_OP_IMM);     // C.LI
          3'b011: begin
            if (rd_full == 5'd2) begin  // C.ADDI16SP
              insn    = enc_i(addi16sp_imm, 5'd2, 3'b000, 5'd2, OPC_OP_IMM);
              illegal = ({cinsn[12], cinsn[6:2]} == 6'b0);
            end else begin              // C.LUI
              insn    = {lui_imm, rd_full, OPC_LUI};
              illegal = ({cinsn[12], cinsn[6:2]} == 6'b0);
            end
          end
          3'b100: begin
            case (cinsn[11:10])
              2'b00: begin  // C.SRLI
                insn    = enc_i({7'b0000000, cinsn[6:2]}, rs1p, 3'b101, rs1p, OPC_OP_IMM);
                illegal = cinsn[12];
              end
              2'b01: begin  // C.SRAI
                insn    = enc_i({7'b0100000, cinsn[6:2]}, rs1p, 3'b101, rs1p, OPC_OP_IMM);
                illegal = cinsn[12];
              end
              2'b10: insn = enc_i(imm6, rs1p, 3'b111, rs1p, OPC_OP_IMM);  // C.ANDI
              default: begin
                case (cinsn[6:5])
                  2'b00:   insn = enc_r(7'b0100000, rs2p, rs1p, 3'b000, rs1p);  // C.SUB
                  2'b01:   insn = enc_r(7'b0000000, rs2p, rs1p, 3'b100, rs1p);  // C.XOR
                  2'b10:   insn = enc_r(7'b0000000, rs2p, rs1p, 3'b110, rs1p);  // C.OR
                  default: insn = enc_r(7'b0000000, rs2p, rs1p, 3'b111, rs1p);  // C.AND
                endcase
                illegal = cinsn[12];  // C.SUBW/C.ADDW: RV64 only
              end
            endcase
          end
          3'b101:  insn = enc_j(j_imm, 5'd0);                 // C.J
          3'b110:  insn = enc_b(b_imm, rs1p, 3'b000);         // C.BEQZ
          default: insn = enc_b(b_imm, rs1p, 3'b001);         // C.BNEZ
        endcase
      end
      // ------------------------------------------------ Quadrant 2
      2'b10: begin
        case (funct3)
          3'b000: begin  // C.SLLI
            insn    = enc_i({7'b0000000, cinsn[6:2]}, rd_full, 3'b001, rd_full, OPC_OP_IMM);
            illegal = cinsn[12];
          end
          3'b010: begin  // C.LWSP
            insn    = enc_i(lwsp_imm, 5'd2, 3'b010, rd_full, OPC_LOAD);
            illegal = (rd_full == 5'd0);
          end
          3'b100: begin
            if (!cinsn[12]) begin
              if (rs2_full == 5'd0) begin  // C.JR
                insn    = enc_i(12'd0, rd_full, 3'b000, 5'd0, OPC_JALR);
                illegal = (rd_full == 5'd0);
              end else begin               // C.MV
                insn = enc_r(7'b0, rs2_full, 5'd0, 3'b000, rd_full);
              end
            end else begin
              if (rs2_full == 5'd0) begin
                if (rd_full == 5'd0) insn = 32'h0010_0073;                        // C.EBREAK
                else insn = enc_i(12'd0, rd_full, 3'b000, 5'd1, OPC_JALR);       // C.JALR
              end else begin               // C.ADD
                insn = enc_r(7'b0, rs2_full, rd_full, 3'b000, rd_full);
              end
            end
          end
          3'b110:  insn = enc_s(swsp_imm, rs2_full, 5'd2, 3'b010);  // C.SWSP
          default: illegal = 1'b1;  // C.FLDSP/C.FLWSP/C.FSDSP/C.FSWSP
        endcase
      end
      default: illegal = 1'b1;  // 32-bit encoding: not for this unit
    endcase
  end

endmodule
