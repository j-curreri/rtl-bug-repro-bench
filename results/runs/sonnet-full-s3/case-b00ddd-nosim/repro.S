#include "hyp.h"
  .text
  .globl test_main
  .globl trap_handler
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_code)

  .align 2
trap_handler:
  csrr t2, mcause
  li t3, 2
  bne t2, t3, bad
  csrr t2, mstatus
  li t3, MSTATUS_MPV
  and t4, t2, t3
  beqz t4, bad        # must have come from virtualized mode
  li t3, MSTATUS_GVA
  and t4, t2, t3
  bnez t4, bad        # GVA must be 0 for illegal instruction
  PASS
bad:
  FAIL(1)

  .align 2
vs_code:
  .word 0x0000000b    # custom-0 opcode, unimplemented -> illegal
  j vs_code
