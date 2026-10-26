/*
 * repro.S - Bug reproducer for hgatp write handling with unsupported MODE
 *
 * RISC-V Hypervisor specification (Section 8.2.14 / hgatp register):
 * "A write to hgatp with an unsupported MODE value is not ignored the way
 *  it is for satp; the fields of hgatp are WARL in the normal way."
 *
 * On a correct core:
 * Writing hgatp with an unsupported MODE value updates the other fields
 * (PPN and VMID) according to normal WARL rules, while MODE remains a legal
 * value (such as Bare / ModeOff = 0).
 *
 * On the buggy CVA6 core:
 * The entire write is ignored when MODE is unsupported; PPN and VMID do not
 * update at all (retaining their old values).
 */

#include "test.h"

.globl test_main
test_main:
    /* Step 0: Ensure hgatp is initialized to 0 */
    csrw hgatp, zero
    csrr t0, hgatp
    bnez t0, fail_init

    /* -------------------------------------------------------------
     * Test 1: Write hgatp with unsupported MODE = 1 (Sv32, invalid on RV64),
     * VMID = 0x12, and PPN = 0x80004 (aligned to 4).
     *
     * On a correct core:
     * - PPN is updated to 0x80004
     * - VMID is updated to 0x12
     * - MODE takes a supported value (0)
     *
     * On the buggy core:
     * - Entire write is ignored because MODE=1 is unsupported
     * - hgatp remains 0
     * ------------------------------------------------------------- */
    li t1, 1
    slli t1, t1, 60         /* MODE = 1 */
    li t2, 0x12
    slli t2, t2, 44         /* VMID = 0x12 */
    or t1, t1, t2
    li t2, 0x80004          /* PPN = 0x80004 */
    or t1, t1, t2

    csrw hgatp, t1
    csrr t3, hgatp

    /* Extract 44-bit PPN: bits 43:0 */
    li t4, 1
    slli t4, t4, 44
    addi t4, t4, -1         /* mask = 0xFFFFFFFFFFF */
    and t5, t3, t4

    /* On buggy core, PPN is 0 (unchanged). On correct core, PPN is 0x80004 */
    li a0, 0x80004
    bne t5, a0, buggy_detected

    /* Check VMID: bits 57:44 */
    srli t6, t3, 44
    li a1, 0x3FFF
    and t6, t6, a1
    li a1, 0x12
    bne t6, a1, fail_vmid

    /* Check MODE: bits 63:60 (must not be unsupported value 1) */
    srli t6, t3, 60
    li a1, 1
    beq t6, a1, fail_mode

    /* -------------------------------------------------------------
     * Test 2: Transition from a known non-zero supported state.
     * First, write supported MODE = 0, VMID = 0x25, PPN = 0x10000.
     * ------------------------------------------------------------- */
    li t1, 0x25
    slli t1, t1, 44
    li t2, 0x10000
    or t1, t1, t2
    csrw hgatp, t1
    csrr t3, hgatp
    bne t3, t1, fail_init

    /* Now write unsupported MODE = 2, VMID = 0x36, PPN = 0x20000 */
    li t1, 2
    slli t1, t1, 60         /* MODE = 2 */
    li t2, 0x36
    slli t2, t2, 44         /* VMID = 0x36 */
    or t1, t1, t2
    li t2, 0x20000          /* PPN = 0x20000 */
    or t1, t1, t2

    csrw hgatp, t1
    csrr t3, hgatp

    /* Check PPN:
     * On buggy core, PPN is still 0x10000 (write ignored).
     * On correct core, PPN is 0x20000.
     */
    and t5, t3, t4
    li a0, 0x20000
    bne t5, a0, buggy_detected

    /* Check VMID: must be 0x36 */
    srli t6, t3, 44
    li a1, 0x3FFF
    and t6, t6, a1
    li a1, 0x36
    bne t6, a1, fail_vmid

    /* Check MODE: must not be unsupported value 2 */
    srli t6, t3, 60
    li a1, 2
    beq t6, a1, fail_mode

    /* All tests passed on correct core */
    PASS

buggy_detected:
    /* On buggy core, write with unsupported MODE did not update other fields */
    FAIL(1)

fail_init:
    FAIL(2)

fail_vmid:
    FAIL(3)

fail_mode:
    FAIL(4)
