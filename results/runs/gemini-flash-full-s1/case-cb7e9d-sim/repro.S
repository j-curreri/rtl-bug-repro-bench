#include "test.h"

.globl trap_handler
.align 2
trap_handler:
    csrr t6, mcause
    li a1, 3                /* Cause 3 = Breakpoint */
    bne t6, a1, fail_unexpected_trap

    /* Disable trigger 0 by writing 0 to tdata1 */
    li t0, 0
    csrw 0x7a0, t0          /* tselect = 0 */
    csrw 0x7a1, t0          /* tdata1 = 0 */

    /* Increment trap counter */
    addi s0, s0, 1

    /* Advance mepc past the faulting 4-byte instruction */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    mret

fail_unexpected_trap:
    FAIL(127)

.globl test_main
test_main:
    PMP_ALLOW_ALL

    li s0, 0                /* s0 = trap counter */

    /* ------------------------------------------------------------
     * Part 1: Verify exact-match trigger (match = 0) works.
     * ------------------------------------------------------------ */
    li t0, 0
    csrw 0x7a0, t0          /* tselect = 0 */

    la t1, exact_buf
    csrw 0x7a2, t1          /* tdata2 = exact address */

    /* mcontrol6: type=6 (bits 63:60), match=0, m=1 (bit 6), load=1 (bit 0) */
    li t2, 6
    slli t2, t2, 60
    ori t2, t2, 0x41
    csrw 0x7a1, t2          /* tdata1 */

    .option push
    .option norvc
    ld t3, 0(t1)            /* Should trigger exact-match breakpoint */
    .option pop

    li t4, 1
    bne s0, t4, fail_exact  /* Exact match must have fired */

    /* ------------------------------------------------------------
     * Part 2: Test NAPOT trigger (match = 1).
     * Configured range: 16 bytes naturally aligned.
     * NAPOT tdata2 encoding: base | ((1 << 3) - 1) = base | 7.
     * ------------------------------------------------------------ */
    li t0, 0
    csrw 0x7a0, t0          /* tselect = 0 */

    la t1, napot_buf        /* 16-byte aligned base */
    ori t3, t1, 7           /* tdata2 = base | 7 */
    csrw 0x7a2, t3

    /* mcontrol6: type=6, match=1 (NAPOT, bit 7), m=1 (bit 6), load=1 (bit 0) */
    li t2, 6
    slli t2, t2, 60
    ori t2, t2, 0xc1        /* 0x80 | 0x40 | 0x01 */
    csrw 0x7a1, t2          /* tdata1 */

    .option push
    .option norvc
    ld t4, 8(t1)            /* Inside range [base, base+15]! Should trigger NAPOT breakpoint */
    .option pop

    li t5, 2
    bne s0, t5, fail_napot  /* On buggy core, fails to fire -> s0 is 1 */

    PASS

fail_exact:
    FAIL(1)

fail_napot:
    FAIL(2)

.data
.balign 16
exact_buf:
    .dword 0x0123456789abcdef
    .dword 0xfedcba9876543210

.balign 16
napot_buf:
    .dword 0x1111222233334444
    .dword 0x5555666677778888
