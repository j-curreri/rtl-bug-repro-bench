#include "harness/test.h"
.globl test_main
test_main:
  csrw hgatp, zero
  li t0, (1<<60) | (0x5<<44) | 0x1000   # unsupported mode, vmid, ppn
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0xfffffffffff
  and t1, t1, t2
  li t2, 0x1000
  bne t1, t2, bad
  PASS
bad:
  FAIL(1)
