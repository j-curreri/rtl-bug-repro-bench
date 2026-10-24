/*
 * repro.S - bug reproducer for CVA6 cv64a6_imafdch_sv39 (CV-X-IF enabled).
 *
 * Bug: with CvxifEn = 1, an illegal instruction executed in VS-mode is offloaded
 * over the CoreV-X-Interface (decoder.sv assigns fu = CVXIF to illegal
 * instructions).  The example coprocessor rejects the transaction, cvxif_fu
 * then raises an illegal-instruction exception with
 *
 *     x_exception_o.gva = CVA6Cfg.RVH ? v_i : 1'b0;
 *
 * and the CSR file writes mstatus.GVA = ex_i.gva on the trap into M-mode.  So an
 * illegal-instruction trap taken out of VS-mode reports mstatus.GVA = 1.  Per
 * the privileged specification GVA may only be set when mtval (or mtval2) is
 * written with a guest virtual address; for an illegal-instruction trap mtval
 * holds the instruction encoding and mtval2 is 0, so GVA must be 0.
 *
 * Test: enter VS-mode, execute a reserved 32-bit encoding that the core routes
 * to the CV-X-IF coprocessor, then trap into M-mode and inspect mstatus.GVA.
 *
 * PASS  : illegal-instruction trap into M-mode with mstatus.GVA = 0 (correct).
 * FAIL(2): mstatus.GVA = 1 on that trap (the bug).
 * FAIL(1): the trap caused by the reserved encoding was not the expected
 *          illegal-instruction exception.
 * FAIL(3): the reserved encoding did not trap at all (not reachable on either
 *          core: the coprocessor never accepts it).

 * Outcome on the two cores:
 *   correct core -> PASS;   buggy core -> FAIL(2).
 */

#include "hyp.h"            /* pulls in test.h */

  .text
  .globl test_main
test_main:
  /* VS-mode fetches/mem accesses need a PMP region (no entry matches otherwise). */
  PMP_ALLOW_ALL

  /* Traps must land in M-mode: never delegate synchronous exceptions. */
  li t0, -1
  csrrc x0, medeleg, t0

  /* Enter VS-mode.  hgatp and vsatp are both bare (reset values), so the guest
   * physical address space is identity-mapped and no page tables are needed:
   * the bug is in the exception plumbing, independent of translation. */
  ENTER_VS(vs_illegal)

  /* ---- VS-mode ---- */
  .align 2
vs_illegal:
  /* Reserved major opcode, 32-bit: the core offloads it to the CV-X-IF, the
   * coprocessor rejects it, the trap into M-mode carries the poisoned gva. */
  .word 0xFFFFFFFF
1:
  /* Not reachable: the illegal instruction always traps. */
  FAIL(3)

/* ---- trap handler, M-mode (crt.S pointed mtvec here) ---- */
  .globl trap_handler
  .align 2
trap_handler:
  /* The trap we caused must be the illegal-instruction exception (cause 2). */
  csrr t6, mcause
  li t5, 2
  bne t6, t5, _fail

  /* mstatus.GVA (bit 38) must be clear: mtval holds the instruction encoding,
   * not a guest virtual address.  A buggy core saved gva = VS-mode flag = 1. */
  csrr t6, mstatus
  li t5, MSTATUS_GVA
  and t6, t6, t5
  bnez t6, _fail_gva

_pass:
  PASS
_fail_gva:
  FAIL(2)
_fail:
  FAIL(1)