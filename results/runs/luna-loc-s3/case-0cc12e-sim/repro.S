#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* FENCE.I requires rd=rs1=0 and imm=0. rd=1 is reserved. */
  .word 0x0000108f          /* FENCE.I x1 */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                  /* illegal instruction */
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
