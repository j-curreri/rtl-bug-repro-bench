#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

  .align 2
vs_code:
  .word 0x00000000        /* illegal instruction */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  csrr t0, mstatus
  li t1, MSTATUS_GVA
  and t0, t0, t1
  bnez t0, bad
  PASS
bad:
  FAIL(2)
