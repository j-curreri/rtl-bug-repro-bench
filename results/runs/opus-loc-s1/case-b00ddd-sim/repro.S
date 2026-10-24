#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw hgatp, zero
  csrw vsatp, zero
  /* clear any stale GVA */
  li t0, MSTATUS_GVA
  csrc mstatus, t0
  ENTER_VS(vs_code)

vs_code:
  /* reserved/custom-3 encoding: illegal, offloaded to CV-X-IF and rejected */
  .word 0x0000707b
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad_cause
  /* MPV must be set (trap from V=1), GVA must be 0 (tval is not a GVA) */
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, bad_mpv
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, bad_gva
  PASS
bad_cause:
  FAIL(2)
bad_mpv:
  FAIL(3)
bad_gva:
  FAIL(4)
