#include "harness/test.h"
.globl test_main
test_main:
  li t1, 0x9
  slli t1, t1, 60
  li t2, 1
  slli t2, t2, 44
  or t1, t1, t2
  li t2, 0x1000
  or t1, t1, t2
  csrw hgatp, t1
  csrr t3, hgatp
  slli t3, t3, 4
  srli t3, t3, 4
  slli t4, t1, 4
  srli t4, t4, 4
  bne t3, t4, 1f
  PASS
1:
  FAIL(1)
