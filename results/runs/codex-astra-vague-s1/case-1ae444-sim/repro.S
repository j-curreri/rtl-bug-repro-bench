#include "test.h"

/*
 * Interrupt entry must write zero to mtval.  The affected decoder retains
 * the interrupted instruction's encoding in its exception payload, and the
 * CSR update path copies that payload into mtval.
 *
 * Use a CLINT machine software interrupt, entirely in M-mode.  All possible
 * interrupted instructions are valid, nonzero encodings.  No synchronous
 * exception or particular interrupt delivery latency is needed.
 */
    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    csrci mstatus, 8             /* Keep interrupts disabled during setup. */
    csrw mie, zero
    csrw mideleg, zero
    la t0, trap_handler
    csrw mtvec, t0

    /* CLINT provides one 32-bit MSIP register per hart. */
    csrr t0, mhartid
    slli t0, t0, 2
    li s0, 0x02000000
    add s0, s0, t0
    sw zero, 0(s0)
    fence iorw, iorw

    /* A sentinel also catches an implementation that fails to update mtval. */
    li t0, 0x1234
    csrw mtval, t0
    li t0, 1
    sw t0, 0(s0)
    fence iorw, iorw

wait_pending:
    csrr t0, mip
    andi t0, t0, 8
    beqz t0, wait_pending

    li t0, 8                    /* mie.MSIE */
    csrw mie, t0
    csrsi mstatus, 8             /* mstatus.MIE */
wait_interrupt:
    addi t1, t1, 1
    j wait_interrupt

    .balign 4
    .globl trap_handler
trap_handler:
    /* Capture the trap values before doing anything else. */
    csrr t2, mcause
    csrr t3, mtval
    csrw mie, zero
    li t0, 0x8000000000000003    /* Interrupt bit | machine software cause. */
    bne t2, t0, unexpected_trap
    sw zero, 0(s0)
    fence iorw, iorw
    bnez t3, bad_mtval
    PASS

bad_mtval:
    FAIL(1)
unexpected_trap:
    FAIL(2)
