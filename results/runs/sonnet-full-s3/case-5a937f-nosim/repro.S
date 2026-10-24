#include "harness/test.h"
.globl test_main
test_main:
  li t1, 0x20
  csrw menvcfg, t1
  csrr t2, menvcfg
  srli t2, t2, 4
  andi t2, t2, 3
  li t3, 2
  beq t2, t3, 1f
  csrw senvcfg, t1
  csrr t2, senvcfg
  srli t2, t2, 4
  andi t2, t2, 3
  beq t2, t3, 1f
  csrw henvcfg, t1
  csrr t2, henvcfg
  srli t2, t2, 4
  andi t2, t2, 3
  beq t2, t3, 1f
  PASS
1:
  FAIL(1)
