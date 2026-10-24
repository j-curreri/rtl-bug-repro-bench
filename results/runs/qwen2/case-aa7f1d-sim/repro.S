/* Bug reproducer: MRET with mstatus.MPP = M and mstatus.MPV = 1 must leave the
 * hart in M-mode with virtualization disabled (V = 0).  The spec says MPV is
 * ignored when MRET returns to M-mode, so the resulting V state must be 0.
 *
 * The buggy core instead leaves V = 1 while priv = M (an inconsistent
 * virtualization state).
 *
 * Detecting the residual V:
 *   G-stage translation is gated on "priv != M", so the MMU will not reveal the
 *   stray V in M-mode.  But taking a trap TO M-mode writes
 *   mstatus.MPV <- (previous V).  So the sequence is:
 *
 *       mret                (MPP=M, MPV=1)  -> buggy: M-mode, V=1 ; correct: M-mode, V=0
 *       ecall               (M-mode env call, traps to M-mode)
 *       read mstatus.MPV    -> 1 on buggy core, 0 on a correct core
 *
 * mstatus.MPV is bit 39; in XLEN64 the full 64-bit value is readable via
 * "csrr mstatus" (mstatush is not exposed in XLEN64).
 */
#include "test.h"

#define MPP_M      (3 << 11)    /* mstatus.MPP = M-mode */
#define MSTATUS_MPV (1 << 39)   /* mstatus.MPV */

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Prepare MRET: return to M-mode (MPP=M) with MPV=1. */
  li   t0, MSTATUS_MPV
  csrs mstatus, t0
  li   t0, MPP_M
  csrs mstatus, t0

  la   t0, body
  csrw mepc, t0
  mret

body:
  /* Now in M-mode; V = 1 on the buggy core, 0 on a correct core.
   * Force an M-mode trap so that mstatus.MPV captures the V state. */
  ecall
1:  j 1b                      /* must not be reached: ecall always traps */

  .align 2
  .globl trap_handler
trap_handler:
  /* M-mode trap: mstatus.MPV was just set to the pre-trap V. */
  csrr t0, mstatus
  srli t0, t0, 39             /* isolate MSTATUS.MPV */
  andi t0, t0, 1
  beqz t0, pass               /* MPV == 0 -> V was 0 -> correct core */
  FAIL(1)
pass:
  PASS
