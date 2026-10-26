#include "test.h"

/* ECALL must set mtval to zero. The buggy core instead exposes the
 * instruction encoding (0x00000073) through mtval.
 */
    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    /* Keep the expected synchronous exception as the only trap source. */
    csrw mie, zero
    li t0, 8
    csrc mstatus, t0
    la t0, trap_handler
    csrw mtvec, t0

    /* A nonzero initial value also detects a failure to update mtval. */
    li t0, 0x1234
    csrw mtval, t0
    la s0, ecall_site
    li s1, 11                  /* Environment call from M-mode. */
ecall_site:
    ecall
    FAIL(1)                    /* ECALL must trap. */

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    bne t0, s1, wrong_cause
    csrr t0, mepc
    bne t0, s0, wrong_pc
    csrr t0, mtval
    bnez t0, wrong_tval
    PASS

wrong_cause:
    FAIL(2)
wrong_pc:
    FAIL(3)
wrong_tval:
    FAIL(4)
