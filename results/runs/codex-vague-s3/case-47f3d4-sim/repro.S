#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* This RV64 configuration implements M and U, but no S-mode.
     * The privileged specification therefore requires mstatus.SXL
     * (bits 35:34) to be read-only zero. The buggy RTL forces it to 2.
     */
    csrr t0, mstatus
    srli t0, t0, 34
    andi t0, t0, 3
    bnez t0, bad_sxl

    PASS

bad_sxl:
    FAIL(1)

    .balign 4
    .globl trap_handler
trap_handler:
    /* No instruction in this test should trap in M-mode. */
    FAIL(2)
