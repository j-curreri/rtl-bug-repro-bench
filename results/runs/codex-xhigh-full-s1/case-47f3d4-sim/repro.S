#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* RV64 mstatus.SXL is bits 35:34.  With no S-mode implemented,
       this field must be read-only zero.  UXL (bits 33:32) is separate
       and may legitimately report RV64 for the implemented U-mode. */
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
