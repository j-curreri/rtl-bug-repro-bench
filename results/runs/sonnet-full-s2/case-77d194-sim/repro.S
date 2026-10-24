#include "harness/test.h"
.globl test_main
test_main:
  csrw hgatp, zero
  li t0, (1 << 60) | (0x5 << 44) | 0x1234
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0xfff
  and t1, t1, t2
  beqz t1, 1f
  PASS
1:
  FAIL(1)
