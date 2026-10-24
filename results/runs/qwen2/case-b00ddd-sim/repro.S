/* Bug: when an illegal instruction executes in VS-mode on a core with the
 * CV-X-IF coprocessor interface enabled, the trap into M-mode reports
 * mstatus.GVA = 1.  For illegal-instruction exceptions mtval holds the
 * faulting instruction, not a guest virtual address, so GVA must be 0.
 *
 * How this reproduces it:
 *   - the decoder routes every instruction it finds illegal to the CVXIF
 *     functional unit when CvxifEn is set (decoder.sv, fu = CVXIF);
 *   - the coprocessor attached to this core does not claim a custom-0
 *     instruction, so the issue transaction is rejected and the CVXIF FU
 *     raises the illegal-instruction exception itself (cvxif_fu.sv), which
 *     on the buggy RTL latches gva = v_i instead of gva = 0;
 *   - executing that instruction in VS-mode makes v_i = 1, so the M-mode
 *     trap entry stores mstatus.GVA = 1 (bug) / 0 (correct).
 *
 * Plan:
 *   1. M-mode: PMP_ALLOW_ALL, point mtvec at our handler.
 *   2. Enter VS-mode (mstatus.MPV = 1, MPP = S, mret).
 *   3. Execute a 32-bit custom-0 instruction (opcode 0b0101011).
 *   4. In the M-mode trap handler verify the trap details and check
 *      that mstatus.GVA is 0.
 *
 * Correct core: GVA == 0 -> PASS.  Buggy core: GVA == 1 -> FAIL(42).
 */
#include "hyp.h"

  .globl test_main
  .globl trap_handler
  .align 2
  test_main:
  PMP_ALLOW_ALL

  la   t0, trap_handler
  csrw mtvec, t0

  /* mret into VS-mode: v_i (virtualization mode) becomes 1 */
  ENTER_VS(vs_code)

  /* must never be reached */
  li   a0, 7
  FAIL(7)

  /* VS-mode code: 32-bit custom-0 instruction.  Not part of the base ISA,
   * so with CvxifEn it is offloaded to the coprocessor; the coprocessor
   * rejects it, which raises the illegal-instruction exception in VS-mode. */
  .align 2
  vs_code:
  .word 0x0000002b
  j    vs_fallthru       /* must never be reached */
  vs_fallthru:
  li   a0, 8
  FAIL(8)

  .align 2
  trap_handler:
  /* expect an illegal-instruction exception (mcause == 2) */
  csrr t0, mcause
  li   t1, 2
  bne  t0, t1, bad_cause

  /* expect the faulting PC to be our custom-0 instruction */
  csrr t1, mepc
  la   t2, vs_code
  bne  t1, t2, bad_epc

  /* sanity: we must have trapped out of virtualized mode (mstatus.MPV == 1) */
  csrr t2, mstatus
  srli t2, t2, 39
  andi t2, t2, 1
  beqz t2, bad_mpv

  /* THE CHECK: mstatus.GVA must be 0 for an illegal-instruction trap:
   * mtval holds the instruction, not a guest virtual address. */
  csrr t0, mstatus
  srli t0, t0, 38
  andi t0, t0, 1
  beqz t0, pass

  FAIL(42)

  bad_cause:
  li   a0, 1
  FAIL(1)
  bad_epc:
  li   a0, 2
  FAIL(2)
  bad_mpv:
  li   a0, 3
  FAIL(3)

  pass:
  PASS
