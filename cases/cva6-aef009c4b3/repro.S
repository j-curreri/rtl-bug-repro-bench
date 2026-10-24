/* On a core without S-mode, mstatus.SXL (bits 35:34) must read as zero. UXL stays 64-bit. */
#include "test.h"
  .text
  .globl test_main
test_main:
  li t0, (1 << 7)              /* touch mstatus (MPIE) so the write path runs */
  csrs mstatus, t0
  csrr t0, mstatus
  srli t1, t0, 34
  andi t1, t1, 3
  bnez t1, 1f
  srli t1, t0, 32
  andi t1, t1, 3
  li t2, 2
  bne t1, t2, 2f
  PASS
1: FAIL(1)
2: FAIL(2)
