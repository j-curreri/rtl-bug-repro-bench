#include "test.h"

/*
 * A nonzero mtval for a breakpoint exception must be the virtual address
 * of the faulting instruction, not its encoding.  The decoder leaves the
 * instruction bits in ex.tval when decoding EBREAK (and C.EBREAK).
 * Accept zero as well: the privileged specification permits platforms to
 * report zero instead of an informative trap value.
 */
    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    li s2, 0
    la s0, breakpoint32
    la s1, after32
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

bad_count:
    FAIL(1)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 3                     /* Breakpoint exception */
    bne t0, t1, bad_cause
    csrr t0, mepc
    bne t0, s0, bad_epc
    csrr t0, mtval
    beqz t0, valid_breakpoint
    bne t0, s0, bad_tval
valid_breakpoint:
    addi s2, s2, 1
    csrw mepc, s1
    mret

bad_cause:
    FAIL(2)
bad_epc:
    FAIL(3)
bad_tval:
    FAIL(4)
