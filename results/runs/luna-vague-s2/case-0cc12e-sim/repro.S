#include "test.h"

  .section .text
  .globl test_main
test_main:
faulting_ecall:
  ecall
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, bad
  csrr t0, mepc
  la t1, faulting_ecall
  bne t0, t1, bad
  csrr t0, mtval
  bnez t0, bad
  PASS
bad:
  FAIL(2)
