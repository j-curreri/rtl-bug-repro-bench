#include "test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, (1<<17)
  csrs mstatus, t0
  ENTER_MODE(1, s_code)
s_code:
  ecall
  FAIL(1)
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 9
  bne t0, t1, bad
  csrr t0, mstatus
  li t1, (1<<17)
  and t0, t0, t1
  bnez t0, bad
  PASS
bad:
  FAIL(2)
