#include "test.h"
.globl test_main
.globl trap_handler
.text
test_main:
  PMP_ALLOW_ALL
  li t0, -1
  csrw mcounteren, t0
  csrw scounteren, zero
  li s1, 0
  ENTER_MODE(0, umode)
umode:
  csrr t1, cycle
  ecall            # reached only if the read did not trap
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad     # expect illegal instruction from the cycle read
  csrr t0, mepc
  la t1, umode
  bne t0, t1, bad
  PASS
bad:
  slli t0, t0, 1
  ori a0, t0, 1
  j _halt

