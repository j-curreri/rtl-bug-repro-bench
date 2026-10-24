#include "test.h"
#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)
  .align 2
vs_code:
  .word 0x0000000b
  FAIL(1)
  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, bad
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, bad2
  PASS
bad: FAIL(2)
bad2: FAIL(3)
