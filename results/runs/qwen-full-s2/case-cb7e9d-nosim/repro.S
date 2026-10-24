/*
 * Bug: Sdtrig mcontrol6 address triggers configured with match=1 (NAPOT) fail to
 * fire for accesses inside the configured naturally aligned range, while
 * exact-match triggers work.
 *
 * Root cause (in triggers_pkg::napot_match64):
 *     is_valid_napot = ((base & (base + 1)) == 0);
 * For any valid NAPOT base whose upper address bits are non-zero (i.e. any base
 * that is not of the form 2^k - 1), (base & (base+1)) != 0, so the function
 * declares the trigger "invalid" and returns 0 for every access.  NAPOT
 * triggers therefore never fire, while exact-match (match=0) still works.
 *
 * This test arms a LOAD address trigger (trigger 0) as an mcontrol6 NAPOT
 * match on the 32-byte naturally aligned region [0x80000000, 0x8000001F]
 * (tdata2 = 0x8000000F, action = breakpoint, M-mode) and then performs a load
 * from 0x80000008, which lies inside that region.
 *
 *   - On a spec-correct core the load raises a breakpoint (mcause = 3).  The
 *     trap handler records that, disarms the trigger, and mrets back so the
 *     load re-executes cleanly.  test_main then sees the flag and PASSes.
 *   - On the buggy core the NAPOT trigger never fires: the load completes with
 *     no trap, the flag stays clear, and test_main FAILs.
 */
#include "test.h"

    .section .data
    .align 3
    .globl got_bp
got_bp:
    .dword 0                 /* set by trap_handler if the breakpoint was taken */

    .text
    .globl test_main
    .align 2
test_main:
    /* Clear the flag */
    li      t0, 0
    la      t4, got_bp
    sd      t0, 0(t4)

    /* ---- Arm a load address trigger (mcontrol6, trigger 0) ----
     *
     * mcontrol6 tdata1 bit layout (this core, RV64):
     *   [63:60] type      = 6 (mcontrol6)
     *   [10:7]  match     = 1 (NAPOT)          -> bit 7
     *   [15:12] action    = 0 (breakpoint)
     *   [  6  ] m         = 1 (M-mode)         -> bit 6
     *   [  0  ] load      = 1                 -> bit 0
     *   [ 21  ] select    = 0 (address match, not data)
     */
    li      t0, 0
    csrw    tselect, t0

    li      t1, 0x6000000000000000   /* type = 6 */
    ori     t1, t1, 0x80            /* match = 1 (NAPOT) */
    ori     t1, t1, 0x40            /* m = 1 */
    ori     t1, t1, 0x1             /* load = 1 */
    csrw    tdata1, t1

    /* tdata2 = 0x8000000F -> NAPOT region [0x80000000, 0x8000001F] */
    li      t2, 0x8000000F
    csrw    tdata2, t2

    fence   ior, ior

    /* ---- Access inside the NAPOT region: 0x80000008 ----
     * Use t5 as the base so that the trap handler (which clobbers t0-t4) does
     * not corrupt it: after the breakpoint mret, this load re-executes with the
     * intact t5 and completes cleanly (the trigger is already disarmed). */
    li      t5, 0x80000008
    ld      t3, 0(t5)              /* on a correct core: breakpoint (mcause=3) */

    fence   ior, ior

    /* ---- Check whether the breakpoint trap was taken ---- */
    la      t4, got_bp
    ld      t0, 0(t4)
    beqz    t0, 1f
    PASS
1:
    FAIL(1)

    /* ---- Trap handler: recognise our breakpoint, record it, disarm, resume ---- */
    .globl trap_handler
    .align 2
trap_handler:
    csrr    t0, mcause
    li      t1, 3                  /* cause 3 = BREAKPOINT */
    bne     t0, t1, 2f            /* not our breakpoint -> unexpected trap */

    /* Record that the trigger fired. */
    li      t2, 1
    la      t4, got_bp
    sd      t2, 0(t4)

    /* Disarm trigger 0: write type = 15 (disabled).  Must happen before mret
     * so the re-executed load does not re-trigger. */
    li      t2, 0
    csrw    tselect, t2
    li      t2, 0xF000000000000000 /* type = 15 (disabled) */
    csrw    tdata1, t2

    mret
2:
    FAIL(127)
