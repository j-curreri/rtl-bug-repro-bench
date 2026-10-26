#include "test.h"

/*
 * cv64a6_imafdc_mu implements M and U modes, but no S mode.
 * The privileged specification requires mstatus.SXL (bits 35:34)
 * to be read-only zero when S mode is not supported.
 * The buggy RTL instead unconditionally drives SXL to XLEN_64 (2).
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
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
    FAIL(2)
