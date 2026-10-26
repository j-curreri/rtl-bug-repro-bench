#include "test.h"

/* Machine interrupts must clear mtval, even when the interrupted instruction
 * has nonzero instruction bits saved in the pipeline's exception metadata. */
    .section .text
    .balign 4
    .globl test_main
test_main:
    csrci mstatus, 8          /* Keep interrupts disabled during setup. */
    csrw mie, zero
    csrw mideleg, zero

    li t0, 0x1234
    csrw mtval, t0            /* Also detect failure to update mtval at all. */

    li t0, 0x02000000        /* CLINT msip for hart 0. */
    li t1, 1
    sw t1, 0(t0)
    fence iorw, iorw

    li t0, 8                 /* mie.MSIE */
    csrw mie, t0
    csrsi mstatus, 8          /* mstatus.MIE */

    /* All instructions here have nonzero encodings. No synchronous exception
     * is needed to expose the stale instruction bits used as mtval. */
    li t2, 100000
1:
    addi t2, t2, -1
    bnez t2, 1b
    FAIL(3)                  /* The expected interrupt never arrived. */

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 0x8000000000000003 /* Machine software interrupt. */
    bne t0, t1, unexpected_trap
    csrr t2, mtval

    /* Acknowledge the level-sensitive interrupt before reporting the result.
     * Trap entry has already cleared mstatus.MIE. */
    csrw mie, zero
    li t0, 0x02000000
    sw zero, 0(t0)
    fence iorw, iorw

    bnez t2, bad_mtval
    PASS

bad_mtval:
    FAIL(2)
unexpected_trap:
    FAIL(1)
