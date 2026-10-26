#include "test.h"

/* PMP granularity readback: with grain G, OFF/TOR clear bits [G-1:0],
 * whereas NAPOT forces only bits [G-2:0] to one. In particular, G=1
 * permits an eight-byte NAPOT region and pmpaddr[0] remains writable.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero
    csrw pmpcfg0, zero

    /* Discover the least significant implemented address bit in OFF mode. */
    li t0, -1
    csrw pmpaddr0, t0
    csrr t1, pmpaddr0
    neg t2, t1
    and t2, t2, t1               /* t2 = 1 << G */
    beqz t2, unexpected
    srli t2, t2, 1
    bnez t2, grain_known
    li t2, 1                    /* G=0 also has no forced-one bits */
grain_known:
    addi t2, t2, -1             /* expected NAPOT forced-one mask */

    /* Zero all writable address bits, then select unlocked NAPOT RWX.
     * Execution remains in M-mode, so this entry cannot block the test.
     */
    csrw pmpaddr0, zero
    li t0, 0x1f
    csrw pmpcfg0, t0
    csrr t3, pmpaddr0
    bne t3, t2, bad_napot
    PASS

bad_napot:
    FAIL(1)
unexpected:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    FAIL(3)
