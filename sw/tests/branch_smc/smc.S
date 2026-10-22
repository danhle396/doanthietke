// smc.S - helpers for branch_smc.c
    .text
    .option push
    .option norvc
    // Taken branch whose target is an ECALL. On the first execution the BTB
    // has no entry -> the branch is mispredicted at EX and the very first
    // instruction on the correct path traps (mcause 11).
    .globl branch_to_ecall, branch_ecall_insn
    .balign 4
branch_to_ecall:
    beq     x0, x0, 1f
    nop
    nop
1:
branch_ecall_insn:
    ecall
    ret
    .option pop

    // Code buffer in RAM, patched at run time (self-modifying code).
    //   word 0: jal x0, +8   (later replaced by addi a0, a0, 1)
    //   word 1: addi a0, a0, 100
    //   word 2: jalr x0, 0(ra)
    .data
    .balign 64
    .globl smc_buf
smc_buf:
    .word 0x0080006F
    .word 0x06450513
    .word 0x00008067
