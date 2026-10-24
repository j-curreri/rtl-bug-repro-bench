#include "harness/test.h"
  .globl test_main
  .globl trap_handler
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li t1, -1
  csrw mtval, t1
  ecall
  PASS
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, bad
  csrr t0, mtval
  bnez t0, bad
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
bad:
  FAIL(1)
