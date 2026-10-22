// faults.S - one faulting instruction per function, located at the entry
// label (= expected mepc). The trap handler skips the instruction.
    .text
    .option push
    .option norvc
    .globl do_illegal
do_illegal:          // illegal instruction, mtval = 0xFFFFFFFF
    .word 0xFFFFFFFF
    ret
    .globl do_ecall
do_ecall:
    ecall
    ret
    .globl do_ebreak
do_ebreak:
#ifdef __riscv_compressed
    .option rvc
    c.ebreak          // 16-bit: the handler must skip 2 bytes
    .option norvc
#else
    ebreak
#endif
    ret
    .globl do_load_mis
do_load_mis:          // a0 = misaligned address
    lw      a0, 0(a0)
    ret
    .globl do_load_mis_h
do_load_mis_h:
    lh      a0, 0(a0)
    ret
    .globl do_store_mis
do_store_mis:
    sw      zero, 0(a0)
    ret
    .globl do_load_fault
do_load_fault:        // a0 = unmapped address
    lw      a0, 0(a0)
    ret
    .globl do_store_fault
do_store_fault:
    sw      zero, 0(a0)
    ret
    .globl do_fetch_fault
do_fetch_fault:       // a0 = unmapped target; fetch_ret = resume address
    la      t1, 1f
    la      t2, fetch_ret
    sw      t1, 0(t2)
    jr      a0
1:  ret
    .globl do_jump_misaligned
do_jump_misaligned:   // a0 = target with bit 1 set (only traps without C)
    jr      a0
    ret
    .balign 4
    .globl misaligned_target
    nop
misaligned_target_m2:
    .half 0x0001      // pad so that misaligned_target = 4k + 2
misaligned_target:
    ret
    .option pop
