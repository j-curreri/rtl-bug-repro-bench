#include "harness/test.h"

    .section .text
    .align 2
    .globl test_main
test_main:
    # Allow access to all memory and clear any state left by startup.
    li      t0, -1
    csrw    pmpaddr0, t0
    li      t0, 0x1f
    csrw    pmpcfg0, t0
    la      t0, trigger_seen
    sd      zero, 0(t0)

    # Trigger 0: mcontrol6, exact address match, M privilege, execute.
    csrw    tselect, zero
    la      t0, watched_instruction
    csrw    tdata2, t0
    li      t0, 0x6000000000000044
    csrw    tdata1, t0

    # The matching instruction must trap. The handler advances past it.
    .option push
    .option norvc
watched_instruction:
    addi    t1, zero, 7
    .option pop

    la      t0, trigger_seen
    ld      t0, 0(t0)
    beqz    t0, failed
    PASS
failed:
    FAIL(1)

    .globl trap_handler
trap_handler:
    csrr    t0, mcause
    li      t1, 3                  # breakpoint exception
    bne     t0, t1, unexpected_trap
    la      t0, trigger_seen
    li      t1, 1
    sd      t1, 0(t0)
    csrr    t0, mepc
    addi    t0, t0, 4              # watched instruction is 32-bit
    csrw    mepc, t0
    mret
unexpected_trap:
    FAIL(2)

    .section .data
    .align 3
trigger_seen:
    .dword 0
