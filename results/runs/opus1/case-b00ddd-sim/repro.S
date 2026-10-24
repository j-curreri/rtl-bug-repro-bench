#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw hedeleg, zero
  csrw medeleg, zero
  ENTER_VS(vs_code)

vs_code:
  .word 0x0000006b          /* reserved major opcode: illegal instruction */
  FAIL(1)                   /* should never get here */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad_cause
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, not_virt
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, gva_set
  PASS
bad_cause:
  FAIL(2)
not_virt:
  FAIL(3)
gva_set:
  FAIL(4)
