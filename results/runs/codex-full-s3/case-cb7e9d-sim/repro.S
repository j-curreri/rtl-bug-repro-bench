#include "test.h"

/* mcontrol6: type=6, dmode=0, action=0 (breakpoint), select=0
 * (address), size=0 (any), s=1, load=1.  Only match changes.
 */
#define LOAD_EXACT 0x6000000000000011
#define LOAD_NAPOT 0x6000000000000091
#define DISABLED   0x6000000000000000

    .section .text
    .option norvc
    .option norelax
    .balign 4
    .globl test_main
test_main:
    csrw mie, zero
    csrw medeleg, zero
    csrw satp, zero
    PMP_ALLOW_ALL

    csrw tselect, zero
    li t0, DISABLED
    csrw tdata1, t0

    /* Control: the same byte load must first hit an exact trigger. */
    li s0, 0
    la s1, exact_load
    la t2, watched_range
    addi t0, t2, 16
    csrw tdata2, t0
    li t0, LOAD_EXACT
    csrw tdata1, t0
    ENTER_MODE(1, exact_load)

exact_load:
    lbu a1, 16(t2)
    ecall                       /* Missing exact-match breakpoint. */
    j exact_load

napot_setup:
    /* A 64-byte naturally aligned range is encoded as base | 31:
     * five trailing ones make the low six address bits don't-care.
     * base+16 is inside the range and differs from tdata2 itself.
     */
    li s0, 1
    la s1, napot_load
    la t2, watched_range
    ori t0, t2, 31
    csrw tdata2, t0
    li t0, LOAD_NAPOT
    csrw tdata1, t0
    ENTER_MODE(1, napot_load)

napot_load:
    lbu a1, 16(t2)
    ecall                       /* Missing NAPOT breakpoint: buggy core. */
    j napot_load

    .balign 4
    .globl trap_handler
trap_handler:
    /* S-mode-only matching leaves this M-mode handler untriggered. */
    li t0, DISABLED
    csrw tdata1, t0
    csrr t0, mcause
    li t1, 9                    /* Environment call from S-mode. */
    beq t0, t1, missing_trigger
    li t1, 3                    /* Breakpoint exception. */
    bne t0, t1, unexpected_trap
    csrr t0, mepc
    bne t0, s1, unexpected_trap
    beqz s0, napot_setup
    PASS

missing_trigger:
    beqz s0, missing_exact
    FAIL(2)
missing_exact:
    FAIL(1)
unexpected_trap:
    FAIL(3)

    .section .data
    .balign 64
watched_range:
    .zero 64
