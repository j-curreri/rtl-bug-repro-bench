#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero
  csrw mideleg, zero
  csrw hgatp, zero
  csrw vsatp, zero
  li s0, 0                 /* trap counter */
  ENTER_VS(vs_code)

vs_code:
  .word 0xffffffff         /* illegal instruction, offloaded to CV-X-IF */
  FAIL(3)                  /* should never get here */

  .align 2
  .globl trap_handler
trap_handler:
  addi s0, s0, 1
  li t0, 1
  bne s0, t0, fail_multi
  csrr t1, mcause
  li t0, 2
  bne t1, t0, fail_cause
  /* must have come from virtualized mode */
  csrr t1, mstatus
  li t0, MSTATUS_MPV
  and t2, t1, t0
  beqz t2, fail_mpv
  li t0, MSTATUS_GVA
  and t2, t1, t0
  bnez t2, fail_gva
  PASS
fail_gva:
  FAIL(1)
fail_cause:
  FAIL(2)
fail_mpv:
  FAIL(4)
fail_multi:
  FAIL(5)
