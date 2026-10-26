#include "test.h"

/* Zicbom specifies xenvcfg.CBIE (bits 5:4) as WARL:
 *   00 = trap, 01 = flush, 11 = invalidate; 10 is reserved.
 * An attempted write of 10 must therefore read back a legal value.
 * Do not require a particular replacement value for the reserved write.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    li t0, 0x20
    csrw 0x30a, t0               /* menvcfg.CBIE <- reserved 10 */
    csrr t1, 0x30a
    andi t1, t1, 0x30
    beq t1, t0, bad_menvcfg

    li t0, 0x20
    csrw 0x10a, t0               /* senvcfg.CBIE <- reserved 10 */
    csrr t1, 0x10a
    andi t1, t1, 0x30
    beq t1, t0, bad_senvcfg

    PASS

bad_menvcfg:
    FAIL(1)
bad_senvcfg:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(127)
