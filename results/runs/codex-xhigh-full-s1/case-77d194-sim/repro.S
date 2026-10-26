#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* Stay in M-mode throughout: hgatp never translates our accesses.
     * Seed Sv39x4 with VMID=1 and PPN=0x80000 (16 KiB aligned).
     */
    li t0, 0x8000100000080000
    csrw hgatp, t0
    csrr t1, hgatp
    bne t1, t0, seed_failed

    /* MODE=1 is unsupported. VMID=2 and PPN=0x80004 are legal on this
     * configuration, with reserved bits and PPN[1:0] all zero.
     * Unlike satp, hgatp must still update these independent WARL fields.
     */
    li t0, 0x1000200000080004
    csrw hgatp, t0
    csrr t1, hgatp

    /* The legal MODE selected for an unsupported input is implementation
     * dependent. Ignore MODE[63:60] and check only the remaining fields.
     * The buggy core retains VMID=1 and PPN=0x80000 instead.
     */
    slli t1, t1, 4
    srli t1, t1, 4
    li t2, 0x0000200000080004
    bne t1, t2, fields_failed

    csrw hgatp, zero
    PASS

seed_failed:
    FAIL(1)
fields_failed:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(3)
