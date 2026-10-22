// ============================================================================
// decoder.sv - RV32I/M + Zicsr + Zifencei instruction decoder (32-bit insns).
//
// Ports:
//   insn       : 32-bit (already decompressed) instruction
//   illegal    : encoding not supported by this configuration
//   rs1/rs2/rd : register indices; use_rs1/use_rs2 tell the hazard unit which
//                source registers are really read
//   rd_we      : instruction writes rd (forced 0 when rd == x0)
//   alu_op, opa_sel, opb_imm, imm_type : datapath control
//   is_*       : instruction class flags
//   funct3     : insn[14:12] (branch cond / mem size / M op / CSR op)
//
// Parameters:
//   ENABLE_M : 0 -> M-extension encodings are illegal
// ============================================================================
// File-scope import: Yosys read_verilog -sv rejects imports in module headers.
/* verilator lint_off IMPORTSTAR */
import rv_pkg::*;
/* verilator lint_on IMPORTSTAR */

module decoder
#(
  parameter bit ENABLE_M = 1'b1
) (
  input  logic [31:0] insn,
  output logic        illegal,
  output logic [4:0]  rs1,
  output logic [4:0]  rs2,
  output logic [4:0]  rd,
  output logic        use_rs1,
  output logic        use_rs2,
  output logic        rd_we,
  output logic [3:0]  alu_op,
  output logic [1:0]  opa_sel,
  output logic        opb_imm,
  output logic [2:0]  imm_type,
  output logic [2:0]  funct3,
  output logic        is_branch,
  output logic        is_jal,
  output logic        is_jalr,
  output logic        is_load,
  output logic        is_store,
  output logic        is_md,
  output logic        is_csr,
  output logic        is_ecall,
  output logic        is_ebreak,
  output logic        is_mret,
  output logic        is_fence_i
);

  logic [6:0] opcode;
  logic [6:0] funct7;
  logic       writes_rd;

  assign opcode = insn[6:0];
  assign funct7 = insn[31:25];
  assign funct3 = insn[14:12];
  assign rs1    = insn[19:15];
  assign rs2    = insn[24:20];
  assign rd     = insn[11:7];
  assign rd_we  = writes_rd && (rd != 5'd0);

  always_comb begin
    illegal    = 1'b0;
    use_rs1    = 1'b0;
    use_rs2    = 1'b0;
    writes_rd  = 1'b0;
    alu_op     = ALU_ADD;
    opa_sel    = OPA_RS1;
    opb_imm    = 1'b0;
    imm_type   = IMM_I;
    is_branch  = 1'b0;
    is_jal     = 1'b0;
    is_jalr    = 1'b0;
    is_load    = 1'b0;
    is_store   = 1'b0;
    is_md      = 1'b0;
    is_csr     = 1'b0;
    is_ecall   = 1'b0;
    is_ebreak  = 1'b0;
    is_mret    = 1'b0;
    is_fence_i = 1'b0;

    case (opcode)
      OPC_LUI: begin
        writes_rd = 1'b1;
        opa_sel   = OPA_ZERO;
        opb_imm   = 1'b1;
        imm_type  = IMM_U;
      end
      OPC_AUIPC: begin
        writes_rd = 1'b1;
        opa_sel   = OPA_PC;
        opb_imm   = 1'b1;
        imm_type  = IMM_U;
      end
      OPC_JAL: begin
        writes_rd = 1'b1;
        is_jal    = 1'b1;
        imm_type  = IMM_J;
      end
      OPC_JALR: begin
        writes_rd = 1'b1;
        is_jalr   = 1'b1;
        use_rs1   = 1'b1;
        imm_type  = IMM_I;
        illegal   = (funct3 != 3'b000);
      end
      OPC_BRANCH: begin
        is_branch = 1'b1;
        use_rs1   = 1'b1;
        use_rs2   = 1'b1;
        imm_type  = IMM_B;
        illegal   = (funct3 == 3'b010) || (funct3 == 3'b011);
      end
      OPC_LOAD: begin
        is_load   = 1'b1;
        writes_rd = 1'b1;
        use_rs1   = 1'b1;
        opb_imm   = 1'b1;
        imm_type  = IMM_I;
        illegal   = (funct3 == 3'b011) || (funct3 == 3'b110) || (funct3 == 3'b111);
      end
      OPC_STORE: begin
        is_store  = 1'b1;
        use_rs1   = 1'b1;
        use_rs2   = 1'b1;
        opb_imm   = 1'b1;
        imm_type  = IMM_S;
        illegal   = (funct3[2] == 1'b1) || (funct3[1:0] == 2'b11);
      end
      OPC_OP_IMM: begin
        writes_rd = 1'b1;
        use_rs1   = 1'b1;
        opb_imm   = 1'b1;
        imm_type  = IMM_I;
        case (funct3)
          3'b000: alu_op = ALU_ADD;
          3'b010: alu_op = ALU_SLT;
          3'b011: alu_op = ALU_SLTU;
          3'b100: alu_op = ALU_XOR;
          3'b110: alu_op = ALU_OR;
          3'b111: alu_op = ALU_AND;
          3'b001: begin
            alu_op  = ALU_SLL;
            illegal = (funct7 != 7'b0000000);
          end
          default: begin  // 3'b101
            alu_op  = funct7[5] ? ALU_SRA : ALU_SRL;
            illegal = (funct7 != 7'b0000000) && (funct7 != 7'b0100000);
          end
        endcase
      end
      OPC_OP: begin
        writes_rd = 1'b1;
        use_rs1   = 1'b1;
        use_rs2   = 1'b1;
        if (funct7 == 7'b0000001) begin
          is_md   = 1'b1;
          illegal = !ENABLE_M;
        end else begin
          case (funct3)
            3'b000: alu_op = funct7[5] ? ALU_SUB : ALU_ADD;
            3'b001: alu_op = ALU_SLL;
            3'b010: alu_op = ALU_SLT;
            3'b011: alu_op = ALU_SLTU;
            3'b100: alu_op = ALU_XOR;
            3'b101: alu_op = funct7[5] ? ALU_SRA : ALU_SRL;
            3'b110: alu_op = ALU_OR;
            default: alu_op = ALU_AND;
          endcase
          if (funct7 == 7'b0100000)
            illegal = (funct3 != 3'b000) && (funct3 != 3'b101);
          else
            illegal = (funct7 != 7'b0000000);
        end
      end
      OPC_MISC_MEM: begin
        // FENCE is a NOP (single in-order hart, no caches);
        // FENCE.I flushes the pipeline at MEM.
        case (funct3)
          3'b000:  ;
          3'b001:  is_fence_i = 1'b1;
          default: illegal = 1'b1;
        endcase
      end
      OPC_SYSTEM: begin
        if (funct3 == 3'b000) begin
          case (insn)
            32'h0000_0073: is_ecall  = 1'b1;
            32'h0010_0073: is_ebreak = 1'b1;
            32'h3020_0073: is_mret   = 1'b1;
            32'h1050_0073: ;  // WFI -> NOP
            default:       illegal   = 1'b1;
          endcase
        end else if (funct3 == 3'b100) begin
          illegal = 1'b1;
        end else begin
          is_csr    = 1'b1;
          writes_rd = 1'b1;
          use_rs1   = !funct3[2];
          imm_type  = IMM_Z;
        end
      end
      default: illegal = 1'b1;
    endcase

    // Only 32-bit encodings reach this decoder.
    if (insn[1:0] != 2'b11) illegal = 1'b1;

    if (illegal) begin
      writes_rd  = 1'b0;
      use_rs1    = 1'b0;
      use_rs2    = 1'b0;
      is_branch  = 1'b0;
      is_jal     = 1'b0;
      is_jalr    = 1'b0;
      is_load    = 1'b0;
      is_store   = 1'b0;
      is_md      = 1'b0;
      is_csr     = 1'b0;
      is_ecall   = 1'b0;
      is_ebreak  = 1'b0;
      is_mret    = 1'b0;
      is_fence_i = 1'b0;
    end
  end

endmodule
