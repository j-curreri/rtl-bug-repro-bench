#include "test.h"
.globl test_main
.globl trap_handler
.text
test_main:
  PMP_ALLOW_ALL
  li t0, (1 << 17)
  csrs mstatus, t0
  ENTER_MODE(1, smode)
smode:
  ecall
  FAIL(1)
.align 2
trap_handler:
  csrr t0, mstatus
  li t1, (1 << 17)
  and t0, t0, t1
  bnez t0, 1f
  PASS
1:
  FAIL(2)
