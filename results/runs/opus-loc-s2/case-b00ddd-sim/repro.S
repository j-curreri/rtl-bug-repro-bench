#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw hgatp, zero
  csrw vsatp, zero
  li s0, 0
  ENTER_VS(guest)

guest:
  li s0, 1
  .word 0xffffffff        /* illegal instruction, offloaded to CVXIF */
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, fail_cause
  beqz s0, fail_mode
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, fail_mpv
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, fail_gva
  PASS
fail_cause:
  FAIL(3)
fail_mode:
  FAIL(4)
fail_mpv:
  FAIL(5)
fail_gva:
  FAIL(6)
