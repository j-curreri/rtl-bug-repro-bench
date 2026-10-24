#include "hyp.h"

/* MRET with MPP=M and MPV=1 must stay in M-mode with V=0 (MPV is ignored).
 * Check 1: sscratch must access the HS sscratch, not vsscratch.
 * Check 2: a subsequent ecall (from M, V=0) must record MPV=0 in mstatus. */
  .text
  .globl test_main
test_main:
  li t0, 0x111
  csrw sscratch, t0
  li t0, 0x222
  csrw vsscratch, t0

  /* MPP = M, MPV = 1 */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  csrr t2, sscratch
  li t3, 0x111
  bne t2, t3, fail1
  ecall
  FAIL(3)

fail1:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, fail4
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, fail2
  PASS
fail2:
  FAIL(2)
fail4:
  FAIL(4)
