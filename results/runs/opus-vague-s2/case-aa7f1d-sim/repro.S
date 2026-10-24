#include "hyp.h"
/* MRET with MPP=M and MPV=1 must leave V=0 (spec: V=MPV only if MPP!=M).
 * After such an MRET, sscratch accesses must hit the real sscratch, not vsscratch. */
  .text
  .globl test_main
test_main:
  csrw sscratch, zero
  csrw vsscratch, zero
  li t0, (3 << 11)
  csrs mstatus, t0          /* MPP = M */
  li t0, MSTATUS_MPV
  csrs mstatus, t0          /* MPV = 1 */
  la t0, 1f
  csrw mepc, t0
  mret
1:
  li t2, 0x1234
  csrw sscratch, t2
  csrr t3, vsscratch
  bnez t3, fail1
  csrr t3, sscratch
  bne t3, t2, fail2
  /* MPV must have been cleared by MRET */
  csrr t3, mstatus
  li t0, MSTATUS_MPV
  and t3, t3, t0
  bnez t3, fail3
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
