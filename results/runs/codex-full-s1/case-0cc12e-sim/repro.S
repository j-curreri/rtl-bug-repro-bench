#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* ECALL must replace mtval with zero, even if it was nonzero. */
    li t0, 0x1234
    csrw mtval, t0

    .option push
    .option norvc
ecall_site:
    ecall
    .option pop
    FAIL(1)                       /* ECALL must trap. */

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 11                     /* Environment call from M-mode. */
    bne t0, t1, wrong_trap

    csrr t0, mepc
    la t1, ecall_site
    bne t0, t1, wrong_trap

    /* ECALL has no informative trap value; instruction bits are invalid. */
    csrr t0, mtval
    bnez t0, wrong_tval
    PASS

wrong_trap:
    FAIL(2)
wrong_tval:
    FAIL(3)
