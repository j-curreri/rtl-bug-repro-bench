#include "test.h"

/*
 * Sdtrig mcontrol6, match=1 (NAPOT), must match ranges at arbitrary
 * naturally aligned addresses, including addresses in DRAM.  The broken
 * napot_match64 rejects tdata2 unless (tdata2 & (tdata2 + 1)) == 0,
 * incorrectly requiring every bit above the trailing ones to be zero.
 *
 * probe is 16-byte aligned.  Encoding probe|7 describes a NAPOT range
 * containing probe.  Only execution in U-mode is enabled, so the M-mode
 * trap handler can safely inspect and disable the trigger.
 */
    .section .text
    .option norvc
    .globl test_main
test_main:
    csrw mie, zero
    csrw medeleg, zero
    PMP_ALLOW_ALL

    csrw tselect, zero
    /* Keep type=6, but disable matching while programming tdata2. */
    li t0, 0x6000000000000000
    csrw tdata1, t0
    la t0, probe
    ori t0, t0, 7
    csrw tdata2, t0

    /* type=6, dmode=0, action=0, match=1, u=1, execute=1. */
    li t0, 0x600000000000008c
    csrw tdata1, t0
    ENTER_MODE(0, probe)

    .balign 16
probe:
    nop
    /* Reaching this ecall means that the required breakpoint was missed. */
    ecall
    j probe

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 3
    bne t0, t1, unexpected_trap
    csrr t0, mepc
    la t1, probe
    bne t0, t1, wrong_pc
    /* Also require that the breakpoint came from U-mode. */
    csrr t0, mstatus
    li t1, (3 << 11)
    and t0, t0, t1
    bnez t0, unexpected_trap
    li t0, 0x6000000000000000
    csrw tdata1, t0
    PASS

unexpected_trap:
    FAIL(1)
wrong_pc:
    FAIL(2)
