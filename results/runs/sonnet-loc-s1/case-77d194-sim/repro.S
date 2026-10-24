#include "harness/test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, user)
user:
  csrr t1, cycle
  ecall
.align 4
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  PASS
bad:
  slli t0,t0,1
  ori a0,t0,1
  j _halt
  FAIL(1)
