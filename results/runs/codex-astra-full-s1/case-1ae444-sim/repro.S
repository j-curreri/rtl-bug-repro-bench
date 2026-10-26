#include "test.h"

/* Machine software interrupts must clear mtval, regardless of the instruction
 * interrupted. Keep MSIP pending before enabling MIE to make delivery reliable.
 */
    .section .text
    .balign 4
    .globl test_main
test_main:
    csrci mstatus, 8
    csrw mie, zero
    csrw mideleg, zero

    /* CLINT MSIP is a 32-bit register, one per hart. */
    csrr t0, mhartid
    slli t0, t0, 2
    li s0, 0x02000000
    add s0, s0, t0
    li t0, 1
    sw t0, 0(s0)
    fence iorw, iorw

    /* Wait for the peripheral write to reach the interrupt input. */
1:
    csrr t0, mip
    andi t0, t0, 8
    beqz t0, 1b

    li t0, 8
    csrw mie, t0
    csrsi mstatus, 8

    /* All instructions here are ordinary, nonzero 32-bit encodings. */
    .option push
    .option norvc
2:
    addi t1, t1, 1
    j 2b
    .option pop

    .balign 4
    .globl trap_handler
trap_handler:
    /* Capture mtval before acknowledging the interrupt. */
    csrr t2, mcause
    csrr t3, mtval
    li t4, 0x8000000000000003
    bne t2, t4, unexpected_trap
    sw zero, 0(s0)
    fence iorw, iorw
    csrw mie, zero
    bnez t3, bad_mtval
    PASS

bad_mtval:
    FAIL(1)
unexpected_trap:
    FAIL(2)
