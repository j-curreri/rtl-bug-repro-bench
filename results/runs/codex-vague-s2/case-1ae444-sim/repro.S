#include "test.h"

/* Interrupts must set mtval to zero.  The buggy decoder leaves the
 * interrupted instruction's encoding in the exception's tval field, and
 * the CSR file copies it into mtval instead of clearing mtval.
 * Use a software-pended SSIP, routed to M-mode, so no timer is needed.
 */
    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    csrci mstatus, 8             /* MIE off during setup. */
    csrw mie, zero
    csrw mideleg, zero           /* Handle SSIP in M-mode. */
    li t0, 0x1234
    csrw mtval, t0               /* Also catch failure to overwrite mtval. */
    li t0, 2                    /* SSIP / SSIE = bit 1. */
    csrs mip, t0
    csrw mie, t0
    csrsi mstatus, 8

    /* Every possible interrupted instruction here has a nonzero encoding.
     * The interrupt remains pending until the handler acknowledges it.
     */
1:  addi t1, t1, 1
    j 1b

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t2, mcause
    csrr t3, mtval
    csrw mie, zero
    csrci mip, 2
    li t0, 0x8000000000000001    /* Interrupt, supervisor software cause. */
    bne t2, t0, unexpected_trap
    bnez t3, bad_mtval
    PASS

unexpected_trap:
    FAIL(1)
bad_mtval:
    FAIL(2)
