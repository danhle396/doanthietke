// vectors.S - test vector table: slot i writes i to mscratch, then enters
// the common trap_entry, so the handler can check which slot was used.
    .section .text.trap, "ax"
    .balign 64
    .globl prio_vector_table
prio_vector_table:
    .option push
    .option norvc
    .irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    j       vstub\n
    .endr
    .irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
vstub\n:
    csrwi   mscratch, \n
    j       trap_entry
    .endr
    .option pop
