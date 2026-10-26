/* Reproducer: an illegal instruction executed in VS-mode that the CVXIF
 * coprocessor rejects must trap with mstatus.GVA = 0. On this core the CVXIF
 * exception path (cvxif_fu.sv) sets gva = v_i, so GVA reads back as 1. The
 * tval of an illegal-instruction trap holds instruction bits, not a guest
 * virtual address, so GVA must stay 0 (Privileged spec, H extension, 9.6.4). */
#include "test.h"
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

vs_code:
  /* Opcode 0x7f is undefined; the decoder marks it illegal, the CVXIF
   * coprocessor rejects it, and the trap is raised by cvxif_fu. */
  .word 0xffffffff
  FAIL(1)                   /* not reached: the illegal instruction must trap */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                  /* ILLEGAL_INSTR */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, 2f               /* GVA set: wrong for an illegal-instruction trap */
  PASS
1:
  FAIL(2)                   /* wrong cause */
2:
  FAIL(3)                   /* GVA erroneously set */
