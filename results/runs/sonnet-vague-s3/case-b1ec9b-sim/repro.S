#include "test.h"
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(0, user)
user:
  ecall
.align 2
trap_handler:
  csrr t0, mstatus
  srli t0, t0, 17
  andi t0, t0, 1
  beqz t0, 1f
  FAIL(1)
1:
  PASS
