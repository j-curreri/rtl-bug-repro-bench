#include "test.h"
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  li s1, 0
  ENTER_MODE(0, umode)
umode:
  csrr t1, cycle
  li a0, 1
  ecall
.balign 4
trap_handler:
  csrr t0, mcause
  li t1, 2
  li t2, 8
  beq t0, t2, bad2
  bne t0, t1, bad
  PASS
bad2:
  FAIL(2)
bad:
  FAIL(1)
