#include "hyp.h"

/*
 * cvxif_fu incorrectly copies V into the exception's GVA field, including
 * illegal-instruction exceptions.  The hypervisor specification requires
 * mstatus.GVA to be zero when mtval does not contain a guest virtual address.
 * Here mtval can only contain zero (the illegal instruction's bits).
 */
    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero
    csrw medeleg, zero
    csrw mideleg, zero
    csrw satp, zero
    csrw vsatp, zero
    csrw hgatp, zero
    PMP_ALLOW_ALL

    /* Both translation stages are Bare; VS executes at its physical address. */
    ENTER_VS(guest_illegal)

    .balign 4
guest_illegal:
    /* An all-zero instruction is guaranteed illegal, even with extensions. */
    .word 0x00000000
    j unexpected

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 2                       /* Illegal instruction. */
    bne t0, t1, unexpected
    csrr t0, mepc
    la t1, guest_illegal
    bne t0, t1, unexpected
    csrr t0, mtval
    bnez t0, unexpected

    csrr t2, mstatus
    li t0, MSTATUS_MPV             /* Confirm the trap came from V=1. */
    and t1, t2, t0
    beqz t1, unexpected
    li t0, MSTATUS_GVA
    and t1, t2, t0
    bnez t1, bad_gva
    PASS

bad_gva:
    FAIL(1)
unexpected:
    FAIL(2)
