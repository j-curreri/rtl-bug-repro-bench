#include "hyp.h"

/*
 * cvxif_fu incorrectly sets exception.gva = v_i for illegal instructions.
 * The hypervisor specification requires mstatus.GVA to be zero unless mtval
 * contains a guest virtual address.  An illegal instruction supplies opcode
 * bits (or zero), not an address, even when the instruction ran in VS-mode.
 *
 * With CvxifEn, the decoder offers illegal instructions to CV-X-IF; rejection
 * raises the exception through cvxif_fu.  The all-zero instruction is required
 * to be illegal by the ISA, including when the compressed extension is present.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero
    csrw medeleg, zero
    csrw mideleg, zero
    csrw hedeleg, zero
    csrw satp, zero
    csrw vsatp, zero
    csrw hgatp, zero
    PMP_ALLOW_ALL

    /* Both translation stages are Bare, so guest code uses DRAM directly. */
    ENTER_VS(guest_illegal)

    .balign 4
guest_illegal:
    .word 0x00000000
    /* Executing past the illegal instruction is also a failure. */
    j unexpected_execution

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 2
    bne t0, t1, wrong_trap
    csrr t0, mepc
    la t1, guest_illegal
    bne t0, t1, wrong_trap

    /* Verify that the trap really came from VS-mode. */
    csrr t2, mstatus
    li t1, MSTATUS_MPV
    and t0, t2, t1
    beqz t0, wrong_origin
    srli t0, t2, 11
    andi t0, t0, 3
    li t1, 1
    bne t0, t1, wrong_origin

    /* This is the distinguishing architectural assertion. */
    li t1, MSTATUS_GVA
    and t0, t2, t1
    bnez t0, bad_gva
    PASS

wrong_trap:
    FAIL(1)
wrong_origin:
    FAIL(2)
bad_gva:
    FAIL(3)
unexpected_execution:
    FAIL(4)
