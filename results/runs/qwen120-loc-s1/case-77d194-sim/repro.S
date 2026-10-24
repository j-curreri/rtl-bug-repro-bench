/* repro.S -- bug reproducer for the CVA6 core (config cv64a6_imafdch_sv39).
 *
 * Bug (core/csr_regfile.sv, MSTATUS write path):
 *   When the H extension is implemented, MSTATUS.MPP = HS (2'b10) is a legal
 *   value: M-mode software enters HS-mode by writing MPP = 2 to MSTATUS and
 *   executing MRET.  The core, however, rejects this write: the condition
 *
 *     if ((mstatus_d.mpp == riscv::PRIV_LVL_HS) |
 *         (!CVA6Cfg.RVS & mstatus_d.mpp == riscv::PRIV_LVL_S) |
 *         (!CVA6Cfg.RVU & mstatus_d.mpp == riscv::PRIV_LVL_U))
 *       mstatus_d.mpp = mstatus_q.mpp;
 *
 *   fires unconditionally on mpp == HS even though CVA6Cfg.RVH = 1, so the
 *   previous MPP is preserved and MPP can never be set to HS.  (The SSTATUS
 *   write path guards the identical check with `if (!CVA6Cfg.RVH)`, which the
 *   MSTATUS path is missing.)  A spec-compliant core keeps MPP = HS.
 *
 * Test (run in M-mode, no virtual memory, no PMP setup needed):
 *   1. Clear MSTATUS.MPP (bits 11:10).
 *   2. Write MSTATUS.MPP = HS (2).
 *   3. Read MSTATUS back: MPP must read back as 2.
 *
 * Correct core:  MPP reads back as 2 -> PASS.
 * Buggy core:    MPP is preserved (0) -> FAIL(1).
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Step 1: clear MSTATUS.MPP (bits 11:10) */
  li   t0, 0x1800
  csrc mstatus, t0

  /* Step 2: write MSTATUS.MPP = HS (2'b10) -- legal when the H extension
            * is implemented */
  li   t0, 0x1000
  csrs mstatus, t0

  /* Step 3: read MSTATUS back and extract MPP */
  csrr t1, mstatus
  li   t3, 0x1800
  and  t2, t1, t3           /* MPP = mstatus[11:10] */

  /* Step 4: MPP must be HS (2) */
  li   t4, 0x1000
  bne  t2, t4, 1f

  PASS
1:
  FAIL(1)

  /* Any unexpected trap: fail with a code identifying the trap cause. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr a0, mcause           /* trap cause */
  addi a0, a0, 200          /* keep it distinct from the logic FAIL codes */
  slli a0, a0, 1
  ori  a0, a0, 1            /* tohost encoding: (code << 1) | 1 */
  j    _halt
