#include "harness/test.h"
.globl test_main
test_main:
  PMP_ALLOW_ALL
  ENTER_MODE(0, umode)
  j 1f
  nop
  nop
1:
umode:
  nop
  mret              # illegal in U-mode: must trap with cause 2
  FAIL(1)
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
