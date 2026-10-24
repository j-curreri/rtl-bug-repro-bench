#include "harness/test.h"
.globl test_main
test_main:
  li t0, -1
  csrw medeleg, t0
  csrr t1, medeleg
  srli t1, t1, 9
  andi t1, t1, 1
  bnez t1, 1f
  FAIL(1)
1: PASS
