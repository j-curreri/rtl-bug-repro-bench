#include "harness/test.h"
.globl test_main
test_main:
  csrw vsscratch, zero
  csrw sscratch, zero
  li t0, (3 << 11)
  csrs mstatus, t0          # MPP = M
  li t0, 1
  slli t0, t0, 39
  csrs mstatus, t0          # MPV = 1
  la t0, 1f
  csrw mepc, t0
  mret
1:
  li t1, 0x55
  csrw sscratch, t1
  csrr t2, vsscratch
  bnez t2, bad
  csrr t2, sscratch
  bne t2, t1, bad
  csrr t2, hstatus          # would trap as virtual instruction if V=1
  PASS
bad:
  FAIL(1)
