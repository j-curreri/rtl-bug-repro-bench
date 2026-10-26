#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  # CY enabled for S/U in mcounteren, but not in scounteren
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, umode)

umode:
  # Spec: U-mode needs both mcounteren and scounteren set, so this must trap (illegal instruction)
  rdcycle t1
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
