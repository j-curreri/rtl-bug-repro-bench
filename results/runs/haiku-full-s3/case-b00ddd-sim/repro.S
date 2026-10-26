#include "hyp.h"

/* Bug: with CV-X-IF enabled, an illegal instruction executed in VS-mode is offloaded to the
 * coprocessor, and the coprocessor's illegal-instruction exception sets gva = v_i. The M-mode
 * trap entry then copies that into mstatus.GVA, which must be 0 for illegal-instruction traps.
 * Bare translation (hgatp = vsatp = 0) is enough: the VS-mode code is identity-mapped. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

  .align 2
vs_code:
  .word 0xffffffff          /* reserved 32-bit encoding: illegal instruction in VS-mode */
  FAIL(1)                   /* not reached: the illegal instruction must trap */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                  /* illegal-instruction cause */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, 1f               /* GVA must be 0 for an illegal-instruction trap */
  PASS
1:
  FAIL(2)
