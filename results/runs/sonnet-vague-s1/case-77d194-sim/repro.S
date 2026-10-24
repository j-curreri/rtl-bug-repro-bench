#include "harness/test.h"
.globl test_main
test_main:
  # hgatp: mode Sv39x4, reserved bits 59:58 set; they must read back as zero
  li t1, 8
  slli t1, t1, 60
  li t0, 3
  slli t0, t0, 58
  or t1, t1, t0
  csrw hgatp, t1
  csrr t2, hgatp
  srli t3, t2, 58
  andi t3, t3, 3
  bnez t3, fail
  srli t3, t2, 60
  li t4, 8
  bne t3, t4, fail
  csrw hgatp, x0
  PASS
fail: FAIL(1)
