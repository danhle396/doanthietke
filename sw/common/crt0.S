// crt0.S - reset entry: set sp/gp, clear .bss, install mtvec, call main,
// pass its return value to exit().
    .section .text.init, "ax"
    .globl _start
_start:
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop
    la      sp, _stack_top

    // clear .bss
    la      t0, _bss_start
    la      t1, _bss_end
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:
    // direct-mode trap vector
    la      t0, trap_entry
    csrw    mtvec, t0

    call    console_init
    call    main
    call    exit
3:  j       3b
