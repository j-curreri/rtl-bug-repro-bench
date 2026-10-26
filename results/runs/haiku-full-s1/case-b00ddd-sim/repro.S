#include "hyp.h"

/* Bug: with CV-X-IF enabled, an illegal instruction executed in VS-mode traps to M-mode
 * with mstatus.GVA = 1. The illegal-instruction trap must leave GVA = 0 because mtval
 * holds the instruction bits, not a guest virtual address.
 *
 * Both stages are left in Bare mode (hgatp = vsatp = 0 after reset), so VS-mode code runs
 * at physical addresses and PMP allows everything. The illegal instruction is not delegated,
 * so it traps to M-mode. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

vs_code:
  .word 0xffffffff          /* 32-bit encoding that is illegal in every extension */
  PASS                      /* only reached if the illegal instruction did not trap */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                  /* illegal instruction */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, 2f               /* GVA set on an illegal-instruction trap: bug */
  PASS
1:
  FAIL(2)                   /* unexpected trap cause */
2:
  FAIL(1)                   /* GVA = 1 */
