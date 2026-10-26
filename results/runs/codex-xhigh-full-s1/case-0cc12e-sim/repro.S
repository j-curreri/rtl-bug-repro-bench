#include "test.h"

    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero

    /* A synchronous ECALL must overwrite mtval with zero.  The buggy
       decoder instead supplies the instruction encoding, 0x00000073. */
    li t0, 0x5a5a5a5a
    csrw mtval, t0

ecall_site:
    ecall
    FAIL(1)                       /* ECALL must trap, never fall through. */

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 11                     /* Environment call from M-mode. */
    bne t0, t1, wrong_cause

    csrr t0, mepc
    la t1, ecall_site
    bne t0, t1, wrong_pc

    /* For an environment call, mtval is required to be zero. */
    csrr t0, mtval
    bnez t0, wrong_mtval
    PASS

wrong_cause:
    FAIL(2)
wrong_pc:
    FAIL(3)
wrong_mtval:
    FAIL(4)
