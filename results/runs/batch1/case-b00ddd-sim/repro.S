#include "hyp.h"
  .text
  .globl test_main
  .globl trap_handler
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero
  ENTER_VS(vs_code)
  .align 2
vs_code:
  .word 0x0000000b      # custom-0, not implemented
  FAIL(1)
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, bad2
  PASS
bad: FAIL(2)
bad2: FAIL(3)
