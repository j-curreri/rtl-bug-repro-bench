#include "test.h"

/* hgatp MODE is WARL: writing an unsupported MODE (9 = Sv48x4) must leave MODE
 * unchanged but still update the other fields (VMID, PPN).
 * Layout (RV64): MODE[63:60] | VMID[57:44] | PPN[43:0].
 * From reset hgatp is 0 (Bare). After writing MODE=9, VMID=5, PPN=0x123450
 * a correct core reads back MODE=0, VMID=5, PPN=0x123450. */

    .section .text
    .globl test_main
test_main:
    li t0, 0x9000500000123450
    csrw hgatp, t0
    csrr t1, hgatp
    li t2, 0x0000500000123450
    bne t1, t2, 1f
    PASS
1:
    FAIL(1)
