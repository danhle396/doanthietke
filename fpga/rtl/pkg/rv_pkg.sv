/* verilator lint_off UNUSEDPARAM */
// Shared constant library: not every constant is used by every module.
package rv_pkg;

  // ---------------- Major opcodes (insn[6:0]) ----------------
  localparam logic [6:0] OPC_LOAD     = 7'b0000011;
  localparam logic [6:0] OPC_MISC_MEM = 7'b0001111;
  localparam logic [6:0] OPC_OP_IMM   = 7'b0010011;
  localparam logic [6:0] OPC_AUIPC    = 7'b0010111;
  localparam logic [6:0] OPC_STORE    = 7'b0100011;
  localparam logic [6:0] OPC_OP       = 7'b0110011;
  localparam logic [6:0] OPC_LUI      = 7'b0110111;
  localparam logic [6:0] OPC_BRANCH   = 7'b1100011;
  localparam logic [6:0] OPC_JALR     = 7'b1100111;
  localparam logic [6:0] OPC_JAL      = 7'b1101111;
  localparam logic [6:0] OPC_SYSTEM   = 7'b1110011;

  // ---------------- ALU operations ----------------
  localparam logic [3:0] ALU_ADD  = 4'd0;
  localparam logic [3:0] ALU_SUB  = 4'd1;
  localparam logic [3:0] ALU_SLL  = 4'd2;
  localparam logic [3:0] ALU_SLT  = 4'd3;
  localparam logic [3:0] ALU_SLTU = 4'd4;
  localparam logic [3:0] ALU_XOR  = 4'd5;
  localparam logic [3:0] ALU_SRL  = 4'd6;
  localparam logic [3:0] ALU_SRA  = 4'd7;
  localparam logic [3:0] ALU_OR   = 4'd8;
  localparam logic [3:0] ALU_AND  = 4'd9;

  // ---------------- ALU operand A select ----------------
  localparam logic [1:0] OPA_RS1  = 2'd0;
  localparam logic [1:0] OPA_PC   = 2'd1;
  localparam logic [1:0] OPA_ZERO = 2'd2;

  // ---------------- Immediate formats ----------------
  localparam logic [2:0] IMM_I = 3'd0;
  localparam logic [2:0] IMM_S = 3'd1;
  localparam logic [2:0] IMM_B = 3'd2;
  localparam logic [2:0] IMM_U = 3'd3;
  localparam logic [2:0] IMM_J = 3'd4;
  localparam logic [2:0] IMM_Z = 3'd5;  // CSR: imm = csr address, uimm in rs1 field

  // ---------------- Branch funct3 ----------------
  localparam logic [2:0] F3_BEQ  = 3'b000;
  localparam logic [2:0] F3_BNE  = 3'b001;
  localparam logic [2:0] F3_BLT  = 3'b100;
  localparam logic [2:0] F3_BGE  = 3'b101;
  localparam logic [2:0] F3_BLTU = 3'b110;
  localparam logic [2:0] F3_BGEU = 3'b111;

  // ---------------- Load/store size (funct3[1:0]) ----------------
  localparam logic [1:0] SZ_B = 2'b00;
  localparam logic [1:0] SZ_H = 2'b01;
  localparam logic [1:0] SZ_W = 2'b10;

  // ---------------- M extension funct3 ----------------
  localparam logic [2:0] MD_MUL    = 3'b000;
  localparam logic [2:0] MD_MULH   = 3'b001;
  localparam logic [2:0] MD_MULHSU = 3'b010;
  localparam logic [2:0] MD_MULHU  = 3'b011;
  localparam logic [2:0] MD_DIV    = 3'b100;
  localparam logic [2:0] MD_DIVU   = 3'b101;
  localparam logic [2:0] MD_REM    = 3'b110;
  localparam logic [2:0] MD_REMU   = 3'b111;

  // ---------------- CSR op (funct3[1:0]) ----------------
  localparam logic [1:0] CSR_RW = 2'b01;
  localparam logic [1:0] CSR_RS = 2'b10;
  localparam logic [1:0] CSR_RC = 2'b11;

  // ---------------- CSR addresses ----------------
  localparam logic [11:0] CSR_MSTATUS       = 12'h300;
  localparam logic [11:0] CSR_MISA          = 12'h301;
  localparam logic [11:0] CSR_MIE           = 12'h304;
  localparam logic [11:0] CSR_MTVEC         = 12'h305;
  localparam logic [11:0] CSR_MSTATUSH      = 12'h310;
  localparam logic [11:0] CSR_MCOUNTINHIBIT = 12'h320;
  localparam logic [11:0] CSR_MHPMEVENT3    = 12'h323;
  localparam logic [11:0] CSR_MHPMEVENT10   = 12'h32A;
  localparam logic [11:0] CSR_MSCRATCH      = 12'h340;
  localparam logic [11:0] CSR_MEPC          = 12'h341;
  localparam logic [11:0] CSR_MCAUSE        = 12'h342;
  localparam logic [11:0] CSR_MTVAL         = 12'h343;
  localparam logic [11:0] CSR_MIP           = 12'h344;
  localparam logic [11:0] CSR_MCYCLE        = 12'hB00;
  localparam logic [11:0] CSR_MINSTRET      = 12'hB02;
  localparam logic [11:0] CSR_MHPMCOUNTER3  = 12'hB03;
  localparam logic [11:0] CSR_MHPMCOUNTER10 = 12'hB0A;
  localparam logic [11:0] CSR_MCYCLEH       = 12'hB80;
  localparam logic [11:0] CSR_MINSTRETH     = 12'hB82;
  localparam logic [11:0] CSR_MHPMCOUNTER3H = 12'hB83;
  localparam logic [11:0] CSR_MHPMCOUNTER10H= 12'hB8A;
  localparam logic [11:0] CSR_CYCLE         = 12'hC00;
  localparam logic [11:0] CSR_TIME          = 12'hC01;
  localparam logic [11:0] CSR_INSTRET       = 12'hC02;
  localparam logic [11:0] CSR_CYCLEH        = 12'hC80;
  localparam logic [11:0] CSR_TIMEH         = 12'hC81;
  localparam logic [11:0] CSR_INSTRETH      = 12'hC82;
  localparam logic [11:0] CSR_MVENDORID     = 12'hF11;
  localparam logic [11:0] CSR_MARCHID       = 12'hF12;
  localparam logic [11:0] CSR_MIMPID        = 12'hF13;
  localparam logic [11:0] CSR_MHARTID       = 12'hF14;
  localparam logic [11:0] CSR_MCONFIGPTR    = 12'hF15;

  // ---------------- Exception causes ----------------
  localparam logic [3:0] EXC_INSN_MISALIGNED  = 4'd0;
  localparam logic [3:0] EXC_INSN_ACCESS      = 4'd1;
  localparam logic [3:0] EXC_ILLEGAL          = 4'd2;
  localparam logic [3:0] EXC_BREAKPOINT       = 4'd3;
  localparam logic [3:0] EXC_LOAD_MISALIGNED  = 4'd4;
  localparam logic [3:0] EXC_LOAD_ACCESS      = 4'd5;
  localparam logic [3:0] EXC_STORE_MISALIGNED = 4'd6;
  localparam logic [3:0] EXC_STORE_ACCESS     = 4'd7;
  localparam logic [3:0] EXC_ECALL_M          = 4'd11;

  // Interrupt cause numbers (mcause = {1'b1, 27'b0, cause})
  localparam logic [3:0] IRQ_MSI = 4'd3;
  localparam logic [3:0] IRQ_MTI = 4'd7;
  localparam logic [3:0] IRQ_MEI = 4'd11;

  // ---------------- Branch target buffer entry types ----------------
  localparam logic [1:0] BT_BRANCH = 2'd0;
  localparam logic [1:0] BT_JAL    = 2'd1;
  localparam logic [1:0] BT_JALR   = 2'd2;

endpackage
/* verilator lint_on UNUSEDPARAM */
