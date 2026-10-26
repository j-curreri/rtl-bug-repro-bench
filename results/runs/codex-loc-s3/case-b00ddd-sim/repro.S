#include "test.h"

/*
 * cvxif_fu incorrectly copies V into the exception's GVA field, including
 * illegal-instruction exceptions.  The hypervisor specification requires GVA
 * to be zero when mtval does not contain a guest virtual address.  Instruction
 * bits reported for an illegal instruction are not a guest virtual address.
 *
 * Run an always-illegal compressed instruction in VS with both translation
 * stages Bare, and take the exception directly to M-mode.
 */
    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero
    csrw medeleg, zero
    csrw mideleg, zero
    PMP_ALLOW_ALL

    csrw satp, zero
    csrw vsatp, zero
    csrw hgatp, zero

    /* MRET enters VS: MPP=S, MPV=1. */
    li t0, (1 << 39)
    csrs mstatus, t0
    ENTER_MODE(1, guest_illegal)

    .balign 4
guest_illegal:
    /* 0x0000 is permanently reserved as an illegal instruction. */
    .2byte 0x0000
    .2byte 0x0000
    j unexpected_execution

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 2
    bne t0, t1, unexpected_trap
    csrr t0, mepc
    la t1, guest_illegal
    bne t0, t1, unexpected_trap

    csrr t0, mstatus
    /* Confirm that the fault actually came from a virtualized context. */
    li t1, (1 << 39)
    and t2, t0, t1
    beqz t2, unexpected_trap

    /* mstatus.GVA (bit 38) must be clear for this illegal instruction. */
    li t1, (1 << 38)
    and t2, t0, t1
    bnez t2, bad_gva
    PASS

bad_gva:
    FAIL(1)
unexpected_trap:
    FAIL(2)
unexpected_execution:
    FAIL(3)
