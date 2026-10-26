#include "test.h"

/* hgatp.MODE is WARL: an unsupported MODE write leaves MODE unchanged, but the
 * other fields (PPN, VMID) must still be written. Here MODE=9 (Sv48x4, not
 * supported by this Sv39x4-only core) is written together with PPN 0x1234.
 * Correct core: MODE stays Bare (0), PPN reads back 0x1234.
 * Buggy core:   the whole write is dropped, so hgatp reads back 0. */
    .section .text
    .globl test_main
test_main:
    li t0, 0
    csrw hgatp, t0
    li t0, ((9 << 60) | 0x1234)
    csrw hgatp, t0
    csrr t1, hgatp
    li t2, 0x1234
    bne t1, t2, 1f
    PASS
1:
    FAIL(1)
