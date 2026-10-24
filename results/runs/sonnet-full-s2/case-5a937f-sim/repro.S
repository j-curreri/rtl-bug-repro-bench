#include "harness/test.h"
.globl test_main
test_main:
  li t0, 0x20
  csrw menvcfg, t0
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  bne t1, t2, ok
  FAIL(1)
ok:
  PASS
