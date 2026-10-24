#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw hgatp, zero
  csrw vsatp, zero
  csrw satp, zero
  li s0, 0                 /* trap counter */
  ENTER_VS(vs_code)

vs_code:
  /* Illegal instruction (custom-3), offloaded to CVXIF and rejected */
  .word 0x0000007b
  /* should not get here */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, fail1
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, fail2           /* must have come from V=1 */
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, fail3           /* GVA must be 0 for illegal instruction */
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
