#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* RV64 mstatus.SXL is bits 35:34. With no S-mode, it is RO-zero. */
    li t0, 3
    slli t0, t0, 34
    csrr t1, mstatus
    and t1, t1, t0
    bnez t1, bad_initial_sxl

    /* Attempt to set both SXL bits, preserving all other status fields. */
    csrs mstatus, t0
    csrr t1, mstatus
    and t1, t1, t0
    bnez t1, bad_written_sxl

    /* Clearing the field must also leave it zero. */
    csrc mstatus, t0
    csrr t1, mstatus
    and t1, t1, t0
    bnez t1, bad_written_sxl

    PASS

bad_initial_sxl:
    FAIL(1)
bad_written_sxl:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t6, mcause
    FAIL(127)
