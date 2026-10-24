#include "harness/test.h"
.globl test_main
test_main:
  csrw hgatp, zero
  li t0, (1<<60) | (1<<44) | 0x1230
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0x0fffffffffffffff
  and t1, t1, t2
  li t3, (1<<44) | 0x1230
  bne t1, t3, bad
  PASS
bad:
  FAIL(1)
