#include "harness/test.h"
.globl test_main
test_main:
  csrw hgatp, zero
  li t0, (1 << 60) | (1 << 44) | 0x1000
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0x1000
  li t3, 0xfffffffffff
  and t4, t1, t3
  bne t4, t2, bad
  srli t1, t1, 44
  li t3, 1
  and t1, t1, t3
  bne t1, t3, bad
  PASS
bad:
  FAIL(1)
