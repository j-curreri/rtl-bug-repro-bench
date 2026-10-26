#include "test.h"

/* ECALL must write zero to mtval.  The buggy core instead copies the
 * instruction encoding (0x00000073) from the decoder into that CSR.
 * Everything runs in M-mode; no translation or delegation is needed.
 */
    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    csrci mstatus, 8
    csrw mie, zero
    csrw medeleg, zero

    /* A nonzero initial value also detects a failure to update mtval. */
    li t0, 0x1234
    csrw mtval, t0

ecall_site:
    ecall
    FAIL(4)                     /* ECALL must trap. */

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 11                   /* Environment call from M-mode. */
    bne t0, t1, bad_cause

    csrr t0, mepc
    la t1, ecall_site
    bne t0, t1, bad_epc

    /* For ECALL, mtval must be zero, not the instruction bits or PC. */
    csrr t0, mtval
    bnez t0, bad_tval
    PASS

bad_cause:
    FAIL(1)
bad_epc:
    FAIL(2)
bad_tval:
    FAIL(3)
