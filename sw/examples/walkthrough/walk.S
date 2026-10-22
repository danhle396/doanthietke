// walk.S - short instruction sequence used for docs/giai_thich/walkthrough_pipeline.md
// and the waveform figures: forwarding, load-use stall, compressed instructions,
// a mispredicted branch, an interrupt (MSI) and an ECALL trap with MRET.
// Built for rv32imc; run on m1c1_bp2 (VCD build) by scripts/make_waves.py.
    .section .text.walk, "ax"
    .p2align 2                      // section alignment 4 (mtvec needs a 4-byte aligned handler)
    .globl main
main:
    la      t0, walk_handler
    csrw    mtvec, t0
    li      t0, 8                   // mie.MSIE
    csrw    mie, t0
    la      a0, walk_data
    li      a1, 0x10002014          // TIMER.MSIP
    .option push
    .option norvc
    .globl walk_start
walk_start:
    lw      t0, 0(a0)               // load
    add     t1, t0, t0              // load-use: 1 stall, then forward from mem_wb
    addi    t2, t1, 1               // forward from ex_mem (rs1)
    add     t3, t2, t1              // ex_mem -> rs1, mem_wb -> rs2
    .option rvc
    c.addi  t3, 4                   // compressed (16-bit) instructions
    c.mv    a2, t3
    c.add   a2, t2
    .option norvc
    beq     t3, t3, 1f              // taken: mispredicted (BTB miss) -> 2-cycle flush
    addi    a3, x0, 1               // wrong path, flushed
    addi    a3, x0, 2               // wrong path, flushed
1:  csrsi   mstatus, 8              // MIE = 1
    sw      x0, 0(a1)               // MSIP = 0 (nothing pending yet)
    li      t4, 1
    sw      t4, 0(a1)               // MSIP = 1 -> machine software interrupt
    addi    a4, x0, 3
    addi    a4, a4, 4
    addi    a4, a4, 5
    ecall                           // exception: mcause 11, handler skips it
    .globl walk_end
walk_end:
    csrci   mstatus, 8
    li      a0, 0
    ret

    .option rvc                     // allow a 2-byte nop as alignment padding
    .balign 4
    .option norvc
walk_handler:                       // MSI: clear MSIP; ECALL: mepc += 4
    csrr    t5, mcause
    bltz    t5, 2f
    csrr    t6, mepc
    addi    t6, t6, 4
    csrw    mepc, t6
    mret
2:  sw      x0, 0(a1)
    mret
    .option pop

    .data
    .balign 4
walk_data:
    .word   0x00000015
