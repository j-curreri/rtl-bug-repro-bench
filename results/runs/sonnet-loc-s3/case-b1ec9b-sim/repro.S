#include "test.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(0, umode)
umode:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 8
  bne t0, t1, bad
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, bad
  PASS
bad:
  FAIL(1)
