#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

  .align 2
vs_code:
  .word 0xffffffff        # illegal instruction in VS-mode
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t2, mcause
  li t3, 2
  bne t2, t3, bad
  csrr t2, mstatus
  li t3, MSTATUS_MPV
  and t4, t2, t3
  beqz t4, bad            # must have come from a virtualized mode
  li t3, MSTATUS_GVA
  and t4, t2, t3
  bnez t4, bad            # GVA must be 0
  PASS
bad:
  FAIL(1)
