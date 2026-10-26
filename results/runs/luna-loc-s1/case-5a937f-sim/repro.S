#include "test.h"

    .section .text
    .globl test_main
test_main:
    /* MENVCFG.FIOM and HENVCFG.FIOM are independent controls. */
    csrw menvcfg, zero
    li t0, 1
    csrw menvcfg, t0
    csrw henvcfg, zero

    csrr t1, menvcfg
    andi t1, t1, 1
    beqz t1, fail_menvcfg_clobbered

    li t0, 1
    csrw henvcfg, t0
    csrw menvcfg, zero
    csrr t1, henvcfg
    andi t1, t1, 1
    beqz t1, fail_henvcfg_clobbered

    PASS

fail_menvcfg_clobbered:
    FAIL(1)
fail_henvcfg_clobbered:
    FAIL(2)

    .globl trap_handler
trap_handler:
    FAIL(3)
