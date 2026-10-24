#include "test.h"
  .text
  .globl test_main
test_main:
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  bnez t1, 1f
  PASS
1:
  FAIL(1)
