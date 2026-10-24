/*
 * Bug reproducer: MRET with mstatus.MPP=M and mstatus.MPV=1 leaves the hart in an
 * inconsistent virtualization state.
 *
 * Per the RISC-V spec, MPV is ignored when returning to M-mode (M-mode has no
 * virtualized sub-state), so the internal virtualization bit V must become 0. This
 * buggy core instead unconditionally latches V = MPV on every MRET, so after an MRET
 * to M-mode with MPV=1 it remains in M-mode but with V=1.
 *
 * V itself is not readable while in M-mode, and MRET clears mstatus.MPV in both the
 * correct and buggy cores. However, any subsequent M-mode trap latches the current
 * virtualization state back into mstatus.MPV (mstatus.MPV <- previous V). So:
 *   1. MRET to M-mode with MPV=1      -> V=1 on buggy core, V=0 on a correct core
 *   2. M-mode ecall -> M-mode trap    -> mstatus.MPV <- V
 *   3. read mstatus.MPV in handler    -> 1 on buggy core (FAIL), 0 on correct (PASS)
 */
#include "test.h"
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* M-mode trap vector -> our handler. */
  la   t0, repro_trap
  csrw mtvec, t0

  /* Raise mstatus.MPV, then MRET back to M-mode (MPP=M).
   *   correct core: MPV ignored for MPP=M -> V = 0
   *   buggy core:   V = MPV = 1 (inconsistent: in M-mode yet virtualized)
   * ENTER_MODE leaves MPV untouched; it only sets MPP=M and mepc=after_mret. */
  li     t0, MSTATUS_MPV
  csrs   mstatus, t0
  ENTER_MODE(3, after_mret)

after_mret:
  /* In M-mode now. Latch the internal V state into mstatus.MPV with an M-mode trap. */
  ecall               /* M-mode ecall -> M-mode trap (medeleg=0): mstatus.MPV <- V */

  /* Correct core: handler mret's past the ecall and we reach PASS. */
  PASS

  .align 2
repro_trap:
  /* On an M-mode trap mstatus.MPV holds the previous virtualization state. It must
   * be 0 after an MRET to M-mode; if set, the core kept an inconsistent V state. */
  csrr t0, mstatus
  li   t1, MSTATUS_MPV
  and  t0, t0, t1
  bnez t0, repro_fail
  /* Correct: skip the ecall and resume. */
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
repro_fail:
  FAIL(1)
