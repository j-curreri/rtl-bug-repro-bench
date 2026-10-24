#include "test.h"
.globl test_main
test_main:
  li t0, 0x20
  csrw menvcfg, t0
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, 1f
  PASS
1:
  FAIL(1)
