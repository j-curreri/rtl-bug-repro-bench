#include "test.h"
  .globl test_main
  .globl trap_handler
  .align 2
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw mcounteren, t0      # cycle allowed for S
  csrw scounteren, zero    # but not for U: U-mode rdcycle must trap
  ENTER_MODE(0, user)
  .align 2
user:
  rdcycle t1
  FAIL(1)                  # no trap: bug
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
