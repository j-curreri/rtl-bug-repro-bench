#include "test.h"
.globl test_main
test_main:
  csrr t0, mstatus
  srli t0, t0, 34
  andi t0, t0, 3
  beqz t0, 1f
  FAIL(1)
1:
  PASS
.globl trap_handler
trap_handler:
  FAIL(2)
