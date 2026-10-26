#include "test.h"

    .section .text
    .balign 4
    .globl test_main
    .type test_main, @function
test_main:
    /* This configuration implements M and U, but no S-mode.  On RV64,
     * mstatus.SXL (bits 35:34) must therefore be read-only zero.
     * Isolate SXL so the implemented UXL field cannot affect the result.
     */
    csrr t0, mstatus
    srli t0, t0, 34
    andi t0, t0, 3
    bnez t0, .Lbad_sxl
    PASS

.Lbad_sxl:
    FAIL(1)
    .size test_main, .-test_main

    .balign 4
    .globl trap_handler
    .type trap_handler, @function
trap_handler:
    /* Reading mstatus in M-mode must not trap. */
    FAIL(2)
    .size trap_handler, .-trap_handler
