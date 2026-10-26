#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* This RV64 configuration implements M and U, but no S-mode.
     * Hence mstatus.SXL (bits 35:34) must be read-only zero.
     * The buggy core instead hardwires it to 2 (RV64).
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
    /* No instruction in this M-mode test should trap. */
    FAIL(2)
