#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  csrw mie, zero
  csrw medeleg, zero
  csrr s0, misa
  PMP_ALLOW_ALL
  csrw satp, zero
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, user_test)

user_test:
  csrr t0, cycle
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, unexpected
  csrr t0, mepc
  la t1, user_test
  bne t0, t1, unexpected
  PASS
unexpected:
  FAIL(2)
