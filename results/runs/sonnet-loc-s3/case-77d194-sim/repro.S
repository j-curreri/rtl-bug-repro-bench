#include "test.h"
  .globl test_main
  .globl trap_handler
  .text
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, umode)
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
umode:
  rdcycle a1
  FAIL(1)
