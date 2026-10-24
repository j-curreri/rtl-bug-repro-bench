#include "hyp.h"
.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw mideleg, zero
  csrw medeleg, zero
  ENTER_VS(vs_code)
vs_code:
  .word 0xffffffff
  PASS_FALLTHRU:
  li a0, 3
  j _halt
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
