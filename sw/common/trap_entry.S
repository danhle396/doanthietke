// trap_entry.S - trap entry/exit.
//   trap_entry        : direct-mode entry (mtvec MODE = 0)
//   trap_vector_table : vectored-mode table (mtvec = table | 1); every slot
//                       jumps to the common entry (cause is read from mcause)
// Saves ra, t0-t6, a0-a7, calls
//   void trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
// and returns with mret (the handler may update mepc to skip an instruction).

    .section .text.trap, "ax"
    .balign 4
    .globl trap_entry
trap_entry:
    addi    sp, sp, -64
    sw      ra,  0(sp)
    sw      t0,  4(sp)
    sw      t1,  8(sp)
    sw      t2, 12(sp)
    sw      t3, 16(sp)
    sw      t4, 20(sp)
    sw      t5, 24(sp)
    sw      t6, 28(sp)
    sw      a0, 32(sp)
    sw      a1, 36(sp)
    sw      a2, 40(sp)
    sw      a3, 44(sp)
    sw      a4, 48(sp)
    sw      a5, 52(sp)
    sw      a6, 56(sp)
    sw      a7, 60(sp)

    csrr    a0, mcause
    csrr    a1, mepc
    csrr    a2, mtval
    call    trap_handler

    lw      ra,  0(sp)
    lw      t0,  4(sp)
    lw      t1,  8(sp)
    lw      t2, 12(sp)
    lw      t3, 16(sp)
    lw      t4, 20(sp)
    lw      t5, 24(sp)
    lw      t6, 28(sp)
    lw      a0, 32(sp)
    lw      a1, 36(sp)
    lw      a2, 40(sp)
    lw      a3, 44(sp)
    lw      a4, 48(sp)
    lw      a5, 52(sp)
    lw      a6, 56(sp)
    lw      a7, 60(sp)
    addi    sp, sp, 64
    mret

    // Vectored table: entry i at BASE + 4*i. Uses 32-bit jumps so each
    // slot is exactly 4 bytes even when the C extension is enabled.
    .balign 64
    .globl trap_vector_table
trap_vector_table:
    .option push
    .option norvc
    .rept 16
    j       trap_entry
    .endr
    .option pop
