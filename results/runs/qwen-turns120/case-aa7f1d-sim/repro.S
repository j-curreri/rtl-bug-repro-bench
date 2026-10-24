/* Reproducer: MRET with mstatus.MPP=M and mstatus.MPV=1 leaves the hart in an
 * inconsistent virtualization state (CVA6, cv64a6_imafdch_sv39).
 *
 * Spec behavior (MRET):
 *   Mstatus.MPV := 0   (step 4)
 *   V           := Mstatus.MPV   (step 8)
 * i.e. V is assigned from the already-cleared MPV, so after MRET V is always 0.
 * When MPP selects M-mode, MPV is simply ignored.
 *
 * Buggy behavior: the core copies the *pre-clear* MPV into V on MRET, so
 * MRET(MPP=M, MPV=1) lands in M-mode with V=1 - an impossible combination.
 *
 * Detection: an M-mode trap entry saves V into Mstatus.MPV (MPV := V), which is
 * the spec-correct behavior shared by both cores. So after MRET(MPP=M, MPV=1),
 * an M-mode trap (ebreak, medeleg=0) gives MPV=0 on a correct core and
 * MPV=1 on the buggy core.
 *
 * Correct core: PASS.  Buggy core: FAIL(1).
 */
#include "test.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* mepc -> after_mret; MPP = M (11); MPV = 1; MPIE = 0 so that MRET leaves
   * MIE = 0 and no M-mode interrupt can disturb the test. */
  la   t0, after_mret
  csrw mepc, t0
  li   t0, (3 << 11) | (1 << 39)    /* MPP = M, MPV = 1 */
  csrs mstatus, t0
  li   t0, (1 << 7)                 /* MPIE = 0 */
  csrc mstatus, t0
  mret

after_mret:
  /* A correct core is now in M-mode with V=0; a buggy core is in M-mode with
   * V=1.  Trap to M-mode: entry records MPV := V.  The handler resumes at
   * `resume` (ebreak may be compressed, so do not assume a 4-byte step). */
  ebreak

resume:
  PASS

/* M-mode trap handler; ebreak is the only trap expected on the correct core. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 3                         /* breakpoint */
  bne  t0, t1, unexpected
  csrr t1, mstatus
  li   t2, (1 << 39)                 /* mstatus.MPV */
  and  t1, t1, t2
  bnez t1, fail                      /* M-mode trap with MPV=1 => V was 1: bug */
  la   t0, resume                    /* resume after ebreak (may be compressed) */
  csrw mepc, t0
  mret

unexpected:
  FAIL(2)

fail:
  FAIL(1)
