/*
 * Reproducer: WARL violation of the CBIE field in menvcfg / senvcfg.
 *
 * The CBIE field (bits [5:4] of menvcfg 0x30a and senvcfg 0x10a) is WARL and
 * must NEVER read back the reserved encoding 2'b10.  On this core the CSR
 * write logic (csr_regfile.sv) maps the written value 2'b10 to the reserved
 * encoding (the `default:` case sets CBIE_RSVD), so after software writes
 * 2'b10 a read-back returns the reserved value 2'b10.
 *
 * Correct core : write CBIE=2'b10 -> read-back is a legal value (0/1/3) -> PASS
 * Buggy core   : write CBIE=2'b10 -> read-back is 2 (reserved)          -> FAIL
 *
 * menvcfg is checked first (M-mode), then senvcfg (also M-mode-accessible).
 * henvcfg is deliberately NOT used: M-mode access to it traps here
 * (illegal instruction) independent of the CBIE bug, so it cannot form part
 * of a reproducer that must PASS on a spec-compliant core.
 */
#include "test.h"

    .section .text
    .globl test_main

test_main:
    /* CBIE mask [5:4], its complement, and the reserved encoding 2'b10. */
    li      s1, 0x30          /* CBIE mask */
    not     s2, s1           /* s2 = ~0x30 (all bits except CBIE) */
    li      s3, 0x20         /* 2'b10 placed in bits[5:4] => bit5 set */

    /* ---- menvcfg.CBIE ([5:4]) ---------------------------------------- */
    /* Preserve the other menvcfg bits, set CBIE = 2'b10, write, read back. */
    csrr    t0, menvcfg
    and     t0, t0, s2
    or      t0, t0, s3
    csrw    menvcfg, t0
    li      s0, 32
dm:
    addi    s0, s0, -1
    bne     s0, zero, dm
    csrr    t2, menvcfg
    and     t2, t2, s1       /* isolate CBIE [5:4] */
    srli    t2, t2, 4        /* t2 = CBIE value (0..3) */
    li      t3, 2            /* reserved encoding 2'b10 */
    beq     t2, t3, fail_m

    /* ---- senvcfg.CBIE ([5:4]) (M-mode access) ------------------------ */
    csrr    t0, senvcfg
    and     t0, t0, s2
    or      t0, t0, s3
    csrw    senvcfg, t0
    li      s0, 32
ds:
    addi    s0, s0, -1
    bne     s0, zero, ds
    csrr    t2, senvcfg
    and     t2, t2, s1
    srli    t2, t2, 4
    li      t3, 2
    beq     t2, t3, fail_s

    /* No register read back a reserved CBIE value: WARL respected. */
    PASS

fail_m:
    FAIL(1)
fail_s:
    FAIL(2)

    /* Any unexpected trap is a spec violation on the buggy core; on a
     * spec-compliant core the accesses above are all legal, so this never
     * runs there. */
    .globl trap_handler
    .align 2
trap_handler:
    csrr    t6, mcause
    FAIL(128)
