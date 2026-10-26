#include "test.h"

/*
 * A breakpoint trap may report zero in mtval, or the virtual address of the
 * EBREAK instruction.  It must not report the EBREAK instruction's encoding.
 *
 * decoder.sv initializes tval to the instruction bits, then selects the
 * breakpoint cause without replacing tval with the instruction address.
 * Keep both specification-permitted mtval choices valid here.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    la s0, breakpoint
    la s1, after_breakpoint
    li s2, 0
breakpoint:
    .option push
    .option norvc
    ebreak
    .option pop
after_breakpoint:
    li t0, 1
    bne s2, t0, fail
    PASS

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 3
    bne t0, t1, fail
    csrr t0, mepc
    bne t0, s0, fail
    csrr t0, mtval
    beqz t0, valid_breakpoint
    bne t0, s0, fail
valid_breakpoint:
    addi s2, s2, 1
    csrw mepc, s1
    mret
fail:
    FAIL(1)
