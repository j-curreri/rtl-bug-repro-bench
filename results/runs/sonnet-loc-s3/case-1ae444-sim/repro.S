#include "test.h"
.globl test_main
test_main:
  li t0, (8<<60) | 0x1234
  csrw hgatp, t0
  csrr s0, hgatp
  li t1, (1<<60) | 0x5678
  csrw hgatp, t1
  csrr t2, hgatp
  bne t2, s0, 1f
  PASS
1: FAIL(1)
