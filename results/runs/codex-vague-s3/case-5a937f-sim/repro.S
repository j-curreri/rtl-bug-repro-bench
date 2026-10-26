#include "test.h"

    .section .text
    .balign 4
    .globl test_main
test_main:
    /* menvcfg.CBIE (bits 5:4) is WARL: 00, 01 and 11 are legal;
     * 10 is reserved. A write of 10 must read back a legal encoding.
     * Do not require any particular choice of that legal encoding.
     */
    csrr s0, 0x30a
    li t0, 0x30
    not t1, t0
    and t1, s0, t1
    ori t1, t1, 0x20
    csrw 0x30a, t1
    csrr t2, 0x30a
    andi t2, t2, 0x30
    csrw 0x30a, s0
    li t0, 0x20
    beq t2, t0, reserved_value
    PASS

reserved_value:
    FAIL(1)

    .balign 4
    .globl trap_handler
trap_handler:
    /* No instruction in this M-mode test should trap. */
    csrr t6, mcause
    FAIL(2)
