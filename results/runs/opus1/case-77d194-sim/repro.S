#include "test.h"

    .text
    .globl test_main
test_main:
    /* start from a known state: MODE=Bare, PPN=0 */
    csrw hgatp, zero
    csrr t0, hgatp
    bnez t0, 1f

    /* MODE=15 (unsupported), PPN=0x1234 (PPN[1:0]=0) */
    li t1, (15 << 60) | 0x1234
    csrw hgatp, t1
    csrr t0, hgatp
    /* PPN field (bits 43:0) must have been written */
    slli t0, t0, 20
    srli t0, t0, 20
    li t2, 0x1234
    bne t0, t2, 2f
    PASS
1:  FAIL(1)
2:  FAIL(2)
