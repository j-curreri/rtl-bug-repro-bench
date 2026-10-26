# Reproducer: hgatp.warl0 (bits 59:58) is WARL-zero and must read back as zero
# after a write. The buggy core only clears PPN[1:0] on write and keeps bits 59:58.
#include "test.h"

    .section .text
    .globl test_main
test_main:
    # Control: with bits 59:58 clear, PPN[1:0] is still hardwired to zero.
    li t0, 0x8000000000012345
    csrw hgatp, t0
    csrr t1, hgatp
    li t2, 0x8000000000012344
    bne t1, t2, 1f

    # Same write with bits 59:58 set. Only bits 59:58 may differ from the control.
    li t0, 0x8C00000000012345
    csrw hgatp, t0
    csrr t1, hgatp
    bne t1, t2, 2f
    PASS
1:  FAIL(1)
2:  FAIL(2)
