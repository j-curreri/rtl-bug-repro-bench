#include "harness/test.h"
.globl test_main
test_main:
  csrw hgatp, zero
  li t0, ((1<<60) | (1<<44) | 0x1000)   # unsupported mode 1, vmid 1, ppn 0x1000
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, ((1<<44) | 0x1000)
  slli t3, t1, 4
  srli t3, t3, 4                         # drop mode field
  bne t3, t2, fail
  PASS
fail:
  FAIL(1)
