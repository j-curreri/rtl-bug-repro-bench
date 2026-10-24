#include "harness/test.h"
.globl test_main
test_main:
  li t0, (1<<9)
  csrw medeleg, t0
  csrr t1, medeleg
  bne t0, t1, 1f
  PASS
1: FAIL(1)
