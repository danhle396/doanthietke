// divs.S - four back-to-back divisions (signed/unsigned quotient/remainder);
// results stored to a3[0..3]. The labels delimit the window in which a timer
// interrupt is expected to cancel a running division.
    .text
    .globl div4, div_window_start, div_window_end
div4:                       // a0 = dividend, a1 = divisor, a2 = result pointer
div_window_start:
    div     t0, a0, a1
    rem     t1, a0, a1
    divu    t2, a0, a1
    remu    t3, a0, a1
div_window_end:
    sw      t0, 0(a2)
    sw      t1, 4(a2)
    sw      t2, 8(a2)
    sw      t3, 12(a2)
    ret
