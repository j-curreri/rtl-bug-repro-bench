#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw hgatp, zero
  csrw vsatp, zero
  ENTER_VS(vs_code)
  .align 2
vs_code:
  .word 0x0000000b      # custom-0, rejected by coprocessor -> illegal instruction
  j vs_code

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad1
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, bad2
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, bad3
  PASS
bad1: FAIL(1)
bad2: FAIL(2)
bad3: FAIL(3)
