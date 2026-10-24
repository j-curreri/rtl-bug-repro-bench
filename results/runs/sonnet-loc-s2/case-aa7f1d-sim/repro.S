#include "test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  li t0, -1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, user)
user:
  csrr t1, cycle
  FAIL(1)          # no illegal-instruction trap: wrong
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
