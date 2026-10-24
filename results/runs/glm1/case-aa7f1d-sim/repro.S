/* Bug reproducer for the CVA6 core (config cv64a6_imafdch_sv39).
 *
 * Bug (csr_regfile.sv, MRET handling): on MRET the virtualization mode V is
 * loaded from mstatus.MPV unconditionally:
 *
 *     if (CVA6Cfg.RVH) begin
 *         v_d = mstatus_q.mpv;      // should happen only when MPP != M-mode
 *         mstatus_d.mpv = 1'b0;
 *     end
 *
 * The privileged specification says MPV is ignored when returning to
 * M-mode, so a hart returning to M-mode must never be in virtualization
 * mode (V = 1 in M-mode is an inconsistent state).
 *
 * How this is observed:
 *   1. Set mstatus.MPP = M-mode, mstatus.MPV = 1, mepc = 1f and execute MRET.
 *      Correct core: back in M-mode with V = 0.
 *      Buggy core:   back in M-mode with V = 1.
 *   2. Take a deterministic trap in M-mode (ecall).  Trapping to M-mode saves
 *      the current virtualization mode into mstatus.MPV, which is 0 on a
 *      correct core and 1 on the buggy core.
 *   3. PASS iff mstatus.MPV reads 0 in the trap frame, otherwise FAIL(1).
 */

#include "test.h"

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* mstatus.MPP = M-mode (0b11), mstatus.MPV = 1 */
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (3 << 11) | (1 << 39)
  csrs mstatus, t0

  la t0, 1f
  csrw mepc, t0
  mret

1:
  /* Both cores are back in M-mode; on the buggy core V = 1 here. */
  ecall

/* Override the weak default trap handler. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mstatus
  slli t0, t0, 24         /* mstatus.MPV (bit 39) -> sign bit 63 */
  bltz t0, 1f             /* MPV set: V was enabled while in M-mode */
  PASS
1:
  FAIL(1)