#include "test.h"

/*
 * EBREAK must report its own PC in mepc.  For a breakpoint exception,
 * mtval may be zero; if nonzero, it must contain the faulting address.
 * The buggy decoder leaves the instruction encoding in exception.tval.
 * Check both the ordinary and compressed encodings, allowing either
 * specification-permitted mtval policy.
 */
    .section .text
    .option norvc
    .option norelax
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero
    la s0, breakpoint32
    la s1, after32
    li s2, 0
breakpoint32:
    ebreak
after32:
    li t0, 1
    bne s2, t0, bad_count
    la s0, breakpoint16
    la s1, after16
breakpoint16:
    .2byte 0x9002                 /* C.EBREAK */
after16:
    li t0, 2
    bne s2, t0, bad_count
    PASS

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 3                     /* breakpoint exception */
    bne t0, t1, bad_cause
    csrr t0, mepc
    bne t0, s0, bad_epc
    csrr t0, mtval
    beqz t0, expected_trap
    bne t0, s0, bad_tval
expected_trap:
    addi s2, s2, 1
    csrw mepc, s1
    mret

bad_cause:
    FAIL(1)
bad_epc:
    FAIL(2)
bad_tval:
    FAIL(3)
bad_count:
    FAIL(4)
