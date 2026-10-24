#include "harness/hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw hgatp, zero
  csrw vsatp, zero
  la t0, trap_handler
  csrw mtvec, t0
  ENTER_VS(vs_code)
vs_code:
  .word 0xffffffff
  j vs_code
.globl trap_handler
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, bad
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, bad
  PASS
bad:
  FAIL(1)
