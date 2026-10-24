#include "hyp.h"

/*
 * Bug: with the hypervisor extension (RVH), MRET does not clear mstatus.GVA.
 *
 * RISC-V H-extension requires MRET to, in addition to
 *     v <- mstatus.MPV ; mstatus.MPV <- 0
 * also perform
 *     mstatus.GVA <- 0
 *
 * This core performs the MPV/v update (csr_regfile.sv, MRET block) but never
 * clears mstatus.GVA (bit 38).  So after an MRET, a previously-set GVA bit
 * lingers.  A spec-correct core clears it; this one does not.
 *
 * Strategy (all in M-mode, no virtual memory needed):
 *   1. Set mstatus.GVA = 1 (M-mode may write mstatus freely).
 *   2. Sanity-check that GVA really is 1.
 *   3. MRET back into M-mode (MPP=M, MPV=0).
 *   4. After the MRET, mstatus.GVA must be 0.  If it is still 1 -> the MRET
 *      failed to clear GVA -> the bug -> FAIL.
 */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  # No interrupts may preempt the sequence.
  csrw mie, zero

  /* --- establish a known baseline: GVA clear --- */
  li t0, MSTATUS_GVA
  csrc mstatus, t0
  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1
  beq t0, zero, gva_baseline_ok
  FAIL(1)                       /* could not clear GVA: unexpected state */
gva_baseline_ok:

  /* --- set GVA = 1, then verify it read back as 1 --- */
  li t0, MSTATUS_GVA
  csrs mstatus, t0
  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1
  bne t0, zero, prepare_mret
  FAIL(2)                       /* GVA not settable via M-mode write */

prepare_mret:
  /* --- MRET back into M-mode: MPP=M, MPV=0, mepc=after_mret --- */
  li t1, (3 << 11)
  csrc mstatus, t1              /* clear MPP */
  li t1, (2 << 11)
  csrs mstatus, t1              /* MPP = M */
  li t1, MSTATUS_MPV
  csrc mstatus, t1              /* MPV = 0 -> v stays 0 */
  la t1, after_mret
  csrw mepc, t1
  mret

after_mret:
  /* Now in M-mode (MPP was M, MPV was 0).
   * Per the H-extension, MRET must have cleared mstatus.GVA. */
  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1
  beq t0, zero, pass_ok
  FAIL(3)                       /* BUG: MRET did not clear mstatus.GVA */
pass_ok:
  PASS
