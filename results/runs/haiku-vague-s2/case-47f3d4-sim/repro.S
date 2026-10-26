#include "test.h"

/* mstatus.MBE (bit 37) is WARL. This core is little-endian only, so the only legal
 * value is 0: writing 1 must not stick. The buggy RTL stores the written MBE value.
 * Save mstatus, try to set MBE, read it back, and restore mstatus before reporting,
 * so the result is reported with normal (little-endian) memory accesses. */
  .globl test_main
test_main:
  csrr t5, mstatus            # save original mstatus
  li t0, 1
  slli t0, t0, 37             # MBE = bit 37
  csrs mstatus, t0            # attempt to set MBE
  csrr t1, mstatus            # read back
  csrw mstatus, t5            # restore before any memory access
  srli t1, t1, 37
  andi t1, t1, 1
  bnez t1, 1f                 # MBE stuck at 1: illegal WARL value
  PASS
1:
  FAIL(1)
