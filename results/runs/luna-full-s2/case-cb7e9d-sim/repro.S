#include "test.h"

    .option norvc
    .section .text
    .globl test_main
test_main:
    /* Configure trigger 0 as an M-mode execute-address NAPOT trigger.
       The tdata2 value encodes the 8-byte range [range_start, range_start+8).
       The watched instruction is at range_start+4, to exercise an interior
       address rather than the exact encoded base. */
    csrw tselect, zero
    la   t0, range_start
    ori  t0, t0, 7                 /* three trailing ones: 8-byte NAPOT */
    csrw tdata2, t0

    li   t0, 0x60000000000000c4    /* type=6, match=1, M=1, execute=1 */
    csrw tdata1, t0

    .align 3
range_start:
    nop                            /* first word in the range */
    .globl watched_instruction
watched_instruction:
    addi t1, t1, 1                 /* second word, must trigger */
after_watched:
    /* Correct core traps before executing the instruction. The handler marks
       the hit and disables the trigger. A missed NAPOT match reaches FAIL. */
    la   t0, trigger_seen
    ld   t1, 0(t0)
    beqz t1, missed_trigger
    PASS

missed_trigger:
    FAIL(1)

    .globl trap_handler
    .align 2
trap_handler:
    /* The only expected exception is a breakpoint at watched_instruction. */
    csrr t0, mcause
    li   t1, 3
    bne  t0, t1, unexpected_trap
    csrr t0, mepc
    la   t1, watched_instruction
    bne  t0, t1, unexpected_trap

    /* Disable before mret so the retried instruction executes without retrap. */
    csrw tdata1, zero
    la   t0, trigger_seen
    li   t1, 1
    sd   t1, 0(t0)
    mret

unexpected_trap:
    FAIL(2)

    .section .bss
    .align 3
trigger_seen:
    .dword 0
