#include "test.h"

# mstatus.SXL (bits 35:34) is the XLEN field for S-mode. With S-mode not
# implemented it must be read-only zero, so writing it must have no effect.

  .section .text.init
  .globl test_main
test_main:
  # Writes to SXL must be ignored: set SXL = 2 (bit 35) and read back.
  li t0, (1 << 35)
  csrs mstatus, t0
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  bnez t1, 1f
  PASS
1:
  FAIL(1)
