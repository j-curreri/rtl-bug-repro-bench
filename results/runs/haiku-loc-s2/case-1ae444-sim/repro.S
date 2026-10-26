#include "test.h"
  .section .text
  .globl test_main
test_main:
  # An ecall from M-mode must raise an environment-call exception (cause 11)
  # and enter trap_handler. On this core it enters debug mode instead.
  ecall
  FAIL(9)

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, 1f
  PASS
1: FAIL(10)
