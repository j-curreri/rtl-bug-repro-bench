/*
 * Bug reproducer: mstatus.GVA wrongly set for illegal-instruction traps in VS-mode.
 *
 * Background
 * ----------
 * With the CV-X-IF coprocessor interface enabled (CvxifEn = 1 in
 * cv64a6_imafdch_sv39_config_pkg.sv), any instruction the main decoder flags as
 * illegal is offloaded to the coprocessor interface (decoder.sv: fu = CVXIF)
 * instead of raising the exception directly.  When the coprocessor rejects the
 * offloaded instruction, core/cvxif_fu.sv raises the illegal-instruction
 * exception.  That exception's `gva` field is computed as:
 *
 *     x_exception_o.gva = CVA6Cfg.RVH ? v_i : 1'b0;   // cvxif_fu.sv
 *
 * For an illegal-instruction trap, mtval holds the instruction *encoding*, not
 * a guest virtual address, so gva (and therefore mstatus.GVA on the trap into
 * M-mode, see csr_regfile.sv: mstatus_d.gva = ex_i.gva) must be 0.  When the
 * trap is taken from a virtualized context (v_i = 1, i.e. VS-mode) the buggy
 * core sets gva = 1, so mstatus.GVA is reported as 1.
 *
 * This test
 * --------
 *  1. Enter VS-mode (v=1, S privilege) using Bare address translation.
 *  2. Execute a custom-0 instruction that the coprocessor interface rejects.
 *  3. That raises an illegal-instruction exception, trapping into M-mode.
 *  4. In M-mode, check mstatus.GVA:
 *        GVA == 0  ->  correct RTL  -> PASS
 *        GVA == 1  ->  buggy  RTL  -> FAIL
 */

#include "test.h"
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Start from a clean mstatus.GVA / mstatus.MPV (both 0 at reset, be explicit). */
  li t0, MSTATUS_GVA | MSTATUS_MPV
  csrc mstatus, t0

  /* Enter VS-mode (v=1, S privilege) at vs_body.  hgatp and vsatp are left in
   * Bare mode, so virtual addresses map identity onto physical memory. */
  ENTER_VS(vs_body)

  .align 2
vs_body:
  /* custom-0 (opcode 0x0B).  Not a standard RISC-V instruction, so the decoder
   * offloads it to the CVXIF interface; the coprocessor does not know it and
   * rejects it, raising an illegal-instruction exception with v_i = 1. */
  .insn 0x0000000b
  /* If the instruction was NOT rejected (some coprocessor handled it) the bug
   * cannot be observed; report that we got here unexpectedly. */
  FAIL(101)

/* ---- M-mode trap handler (overrides the weak default in crt.S) ---- */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li   t1, 2                       /* CAUSE_ILLEGAL_INSTR */
  bne  t0, t1, th_fail_cause       /* unexpected trap cause */

  csrr t0, mstatus

  /* Sanity: we must have trapped from a virtualized context (MPV set). */
  li   t1, MSTATUS_MPV
  and  t2, t0, t1
  beqz t2, th_fail_mpv

  /* GVA: correct RTL leaves it 0; the buggy core sets it to 1. */
  li   t1, MSTATUS_GVA
  and  t2, t0, t1
  bnez t2, th_fail_gva             /* GVA set -> bug */

  PASS                             /* GVA clear -> correct */

th_fail_gva:
  FAIL(42)                         /* mstatus.GVA wrongly set on illegal-instr trap */
th_fail_mpv:
  FAIL(43)                         /* not a VS-mode trap; test misconfigured */
th_fail_cause:
  FAIL(127)                        /* not an illegal-instruction trap */
