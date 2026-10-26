#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* With S-mode absent, mcounteren alone controls U-mode counter access. */
  li t0, 1
  csrw mcounteren, t0
  la t0, user_test
  csrw mepc, t0
  li t0, (3 << 11)
  csrc mstatus, t0
  mret

user_test:
  csrr t1, cycle
  ecall

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 8
  bne t0, t1, fail
  PASS

fail:
  FAIL(1)
