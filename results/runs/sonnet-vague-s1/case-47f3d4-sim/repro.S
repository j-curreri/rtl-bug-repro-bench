#include "test.h"
.globl test_main
test_main:
  csrr t0, misa
  srli t0, t0, 18
  andi t0, t0, 1
  bnez t0, skip        # S supported: nothing to check
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  bnez t1, bad         # SXL must be 0 without S-mode
  li t0, -1
  csrw mstatus, t0
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  bnez t1, bad
skip:
  PASS
bad:
  FAIL(1)
