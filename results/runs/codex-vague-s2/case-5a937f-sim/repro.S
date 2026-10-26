#include "test.h"

/*
 * Zicbom defines envcfg.CBIE (bits 5:4) as WARL, with legal values
 * 00 (trap), 01 (flush), and 11 (invalidate).  The encoding 10 is
 * reserved.  An attempted write of 10 must read back a legal value;
 * do not assume which legal value the implementation selects.
 *
 * Run entirely in M-mode, where both CSRs are accessible.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    li t0, 0x30                 /* CBIE mask */
    li t1, 0x20                 /* reserved CBIE encoding */

    csrr s0, 0x30a              /* preserve menvcfg */
    csrc 0x30a, t0              /* establish legal CBIE=00 */
    csrs 0x30a, t1              /* attempt CBIE=10 */
    csrr t2, 0x30a
    and t2, t2, t0
    csrw 0x30a, s0
    beq t2, t1, bad_menvcfg

    csrr s0, 0x10a              /* preserve senvcfg */
    csrc 0x10a, t0
    csrs 0x10a, t1
    csrr t2, 0x10a
    and t2, t2, t0
    csrw 0x10a, s0
    beq t2, t1, bad_senvcfg

    PASS

bad_menvcfg:
    FAIL(1)
bad_senvcfg:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    FAIL(127)
