#include "test.h"
  .text
  .globl test_main
test_main:
  li t0, 2
  li t1, 3
  add t2, t0, t1
  li t3, 5
  bne t2, t3, 1f
  PASS
1:
  FAIL(1)
