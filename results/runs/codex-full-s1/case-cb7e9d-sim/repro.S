#include "test.h"

/* mcontrol6: type=6, dmode=0, action=0 (breakpoint), select=0
 * (address), size=0 (any size), m=1, load=1.
 */
#define MC6_DISABLED  0x6000000000000000
#define MC6_EXACT_LD  0x6000000000000041
#define MC6_NAPOT_LD  0x60000000000000c1

    .section .text
    .option norvc
    .globl test_main
test_main:
    csrw mie, zero
    csrw medeleg, zero
    csrw tselect, zero
    li t0, MC6_DISABLED
    csrw tdata1, t0
    li s2, 0                      /* Number of expected breakpoints. */
    la s4, watched
    addi s4, s4, 16

    /* Positive control: the same load address must match exactly. */
    csrw tdata2, s4
    la s0, exact_load
    li t0, MC6_EXACT_LD
    csrw tdata1, t0
exact_load:
    ld t2, 0(s4)
    li t0, 1
    bne s2, t0, missing_exact

    /* A 64-byte naturally aligned range is encoded as base | 31.
     * The access at base+16 is strictly inside it, and is different
     * from the encoded tdata2 address.
     */
    la t0, watched
    ori t0, t0, 31
    csrw tdata2, t0
    la s0, napot_load
    li t0, MC6_NAPOT_LD
    csrw tdata1, t0
napot_load:
    ld t2, 0(s4)
    li t0, 2
    bne s2, t0, missing_napot
    PASS

missing_exact:
    FAIL(1)
missing_napot:
    FAIL(2)

    .balign 4
    .globl trap_handler
trap_handler:
    csrr t0, mcause
    li t1, 3                      /* Breakpoint exception. */
    bne t0, t1, unexpected_trap
    csrr t0, mepc
    bne t0, s0, unexpected_trap

    /* Disable the trigger before returning past the trapped load.
     * All instructions are four bytes because of .option norvc.
     */
    li t1, MC6_DISABLED
    csrw tdata1, t1
    addi s2, s2, 1
    addi t0, t0, 4
    csrw mepc, t0
    mret
unexpected_trap:
    FAIL(3)

    .section .data
    .balign 64
watched:
    .zero 64
