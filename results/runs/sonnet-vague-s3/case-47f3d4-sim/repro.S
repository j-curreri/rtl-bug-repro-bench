#include "test.h"
.globl test_main
test_main:
  # No S-mode in this config: mstatus.SXL (bits 35:34) must read as 0.
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  beqz t1, 1f
  FAIL(1)
1:
  PASS
