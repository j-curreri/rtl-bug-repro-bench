#include "test.h"
.globl test_main
test_main:
  # Without S-mode, mstatus.SXL and mstatus.SBE are read-only zero.
  li t0, 1<<37
  csrs mstatus, t0
  csrr t1, mstatus
  csrc mstatus, t0
  srli t2, t1, 36
  andi t2, t2, 1        # SBE
  srli t3, t1, 34
  andi t3, t3, 3        # SXL
  beqz t2, ok
  beqz t3, ok
  FAIL(1)
ok:
  PASS
