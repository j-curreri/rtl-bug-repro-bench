#include "test.h"
#include "hyp.h"
.text
.globl test_main
test_main:
  li t0, 0x1234
  csrw sscratch, t0
  li t0, 0x5678
  csrw vsscratch, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  csrr t1, sscratch
  li t0, 0x1234
  bne t0, t1, 2f
  csrr t1, hstatus
  PASS
2:
  FAIL(1)
