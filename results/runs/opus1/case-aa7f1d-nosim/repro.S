/* MRET with MPP=M and MPV=1 must leave V=0 (MPV is ignored when returning to M).
 * The test then does an ECALL from M-mode: the trap must report cause 11 and
 * write MPV = V = 0 and MPP = M. The buggy core sets V=1, so MPV comes back as 1. */
#include "test.h"
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw hgatp, zero
  csrw satp, zero

  /* MPP = M, MPV = 1 */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  /* MRET always clears MPV */
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, fail_mpv_after_mret
  ecall
  /* trap handler doesn't return here */
  FAIL(9)

fail_mpv_after_mret:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, fail_cause
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  bnez t2, fail_mpv
  srli t2, t0, 11
  andi t2, t2, 3
  li t1, 3
  bne t2, t1, fail_mpp
  PASS
fail_cause:
  FAIL(3)
fail_mpv:
  FAIL(4)
fail_mpp:
  FAIL(5)
