/* Reproducer: hgatp bits 59:58 are reserved (WARZ) in RV64 and must read back as zero
 * after a write. The buggy core stores them. A legal Sv39x4 write must read back unchanged. */
#include "test.h"

    .section .text
    .globl test_main
test_main:
    /* Reserved bits 59:58 set, mode Bare: must read back as zero */
    li t0, 0x0C00000000000000
    csrw hgatp, t0
    csrr t1, hgatp
    bnez t1, 1f

    /* Legal Sv39x4 mode with a 16 KiB-aligned PPN: must read back unchanged */
    li t0, (8 << 60) | 0x1000
    csrw hgatp, t0
    csrr t1, hgatp
    li t2, (8 << 60) | 0x1000
    bne t1, t2, 2f

    PASS
1:  FAIL(1)
2:  FAIL(2)
