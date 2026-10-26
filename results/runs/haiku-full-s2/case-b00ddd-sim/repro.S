#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_VS(vs_entry)

  .align 2
vs_entry:
  /* Illegal instruction in VS-mode. With CV-X-IF enabled it is offloaded and rejected. */
  .word 0xffffffff
  /* Only reached if the illegal instruction did not trap. */
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2                  /* illegal instruction */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, (1 << 38)          /* mstatus.GVA */
  and t0, t0, t1
  bnez t0, 2f
  PASS
1:
  FAIL(1)
2:
  FAIL(2)
