#include "test.h"

/*
 * Unlike satp, hgatp has individually WARL fields: an unsupported MODE
 * must not discard a write to the other fields.  In particular, a legal
 * PPN must still be written.  This implementation incorrectly gates the
 * whole register update on MODE being Bare or Sv39x4.
 *
 * Stay in M-mode throughout, so none of these roots is ever dereferenced.
 * Both PPNs are 16-KiB aligned, as required for an Sv39x4 root.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    /* First establish that the PPN we will test is implemented. */
    li t0, 0x8000000000080004
    csrw hgatp, t0
    csrr t1, hgatp
    slli t1, t1, 20
    srli t1, t1, 20
    li t2, 0x80004
    bne t1, t2, bad_setup

    /* Give the PPN field a distinguishable initial value. */
    li t0, 0x8000000000080000
    csrw hgatp, t0

    /* MODE=15 is reserved/unsupported; PPN=0x80004 is legal. */
    li t0, 0xf000000000080004
    csrw hgatp, t0
    csrr t1, hgatp
    slli t1, t1, 20
    srli t1, t1, 20
    bne t1, t2, lost_ppn_write

    csrw hgatp, zero
    PASS

bad_setup:
    FAIL(1)
lost_ppn_write:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(3)
