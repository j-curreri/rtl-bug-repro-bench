#include "test.h"

/* RV64 mcontrol6: type=6, dmode=0, action=0 (breakpoint),
 * select=0 (address), size=0 (any), s=1, load=1.
 */
#define LOAD_EXACT 0x6000000000000011
#define LOAD_NAPOT 0x6000000000000091
#define DISABLED   0x6000000000000000

    .section .text
    .option norvc
    .balign 4
    .globl test_main
test_main:
    li s0, 0
    li s1, 0
    csrw mie, zero
    csrw medeleg, zero
    csrw satp, zero
    sfence.vma
    PMP_ALLOW_ALL

    csrw 0x7a0, zero           /* tselect = 0 */
    li t0, DISABLED
    csrw 0x7a1, t0             /* tdata1 */
    la s2, watched_range

    /* First prove that this trigger and the trap path work with match=0. */
    li s0, 1
    la s1, exact_load
    addi t0, s2, 16
    csrw 0x7a2, t0             /* tdata2 = exact load address */
    li t0, LOAD_EXACT
    csrw 0x7a1, t0
    ENTER_MODE(1, exact_load)

exact_load:
    ld t1, 16(s2)
    FAIL(1)                    /* The exact-match breakpoint was missing. */

setup_napot:
    /* A 64-byte-aligned base with five trailing ones encodes a NAPOT
     * range containing base+16. Its nonzero upper bits expose the bug.
     */
    li s0, 2
    la s1, napot_load
    ori t0, s2, 31
    csrw 0x7a2, t0
    li t0, LOAD_NAPOT
    csrw 0x7a1, t0
    ENTER_MODE(1, napot_load)

napot_load:
    ld t1, 16(s2)
    FAIL(2)                    /* The NAPOT breakpoint was missing. */

    .balign 4
    .globl trap_handler
trap_handler:
    /* Disable before checking the trap; no handler load can retrigger. */
    li t0, DISABLED
    csrw 0x7a1, t0
    csrr t0, mcause
    li t1, 3                   /* Breakpoint exception, not an interrupt. */
    bne t0, t1, unexpected_trap
    csrr t0, mepc
    bne t0, s1, unexpected_trap

    li t0, 1
    beq s0, t0, setup_napot
    li t0, 2
    bne s0, t0, unexpected_trap
    PASS

unexpected_trap:
    FAIL(3)

    .section .data
    .balign 64
watched_range:
    .zero 64
