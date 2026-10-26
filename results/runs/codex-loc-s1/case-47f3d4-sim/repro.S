#include "test.h"

/*
 * RV64 mstatus.SXL occupies bits 35:34.  The privileged specification
 * requires it to be read-only zero when supervisor mode is unsupported.
 * This configuration implements M and U, but not S.
 *
 * csr_regfile.sv unconditionally assigns XLEN_64 to mstatus_d.sxl on
 * RV64, so the buggy core reads SXL=2 and takes the failure branch.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    /* Verify that this is the specified configuration. */
    csrr t0, misa
    li t1, (1 << 18)             /* misa.S */
    and t0, t0, t1
    bnez t0, wrong_config

    csrr t0, mstatus
    srli t0, t0, 34
    andi t0, t0, 3
    bnez t0, bad_sxl

    /* SXL must remain zero after an attempted write as well. */
    li t1, (3 << 34)
    csrs mstatus, t1
    csrr t0, mstatus
    and t0, t0, t1
    bnez t0, bad_sxl
    PASS

bad_sxl:
    FAIL(1)
wrong_config:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    FAIL(3)
