#include "test.h"

/*
 * ECALL must set mtval to zero, with mcause identifying the originating
 * privilege mode and mepc pointing at ECALL itself.
 *
 * The buggy decoder leaves the ECALL encoding (0x00000073) in ex.tval,
 * and the trap CSR logic copies it to mtval when ZERO_TVAL is disabled.
 * Seed mtval first so that failing to update the CSR is also detected.
 */
    .section .text
    .balign 4
    .option norvc
    .globl test_main
test_main:
    csrci mstatus, 8
    csrw mie, zero
    csrw medeleg, zero
    la t0, trap_handler
    csrw mtvec, t0

    li t0, 0x1234
    csrw mtval, t0
    la s0, ecall_site

ecall_site:
    ecall
    /* An ECALL that does not trap is a failure. */
    FAIL(1)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 11                   /* Environment call from M-mode. */
    bne t0, t1, bad_cause

    csrr t0, mepc
    bne t0, s0, bad_epc

    csrr t0, mtval
    bnez t0, bad_tval
    PASS

bad_cause:
    FAIL(2)
bad_epc:
    FAIL(3)
bad_tval:
    FAIL(4)
