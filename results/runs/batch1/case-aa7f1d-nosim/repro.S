#include "test.h"
.globl test_main
.globl trap_handler
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li t0, (3<<11)
  csrs mstatus, t0
  li t0, (1<<39)
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  ecall
  FAIL(1)
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, bad
  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, bad
  PASS
bad:
  FAIL(2)
