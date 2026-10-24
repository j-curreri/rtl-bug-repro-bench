#include "test.h"

/* S-mode is not implemented, so mstatus.SXL (bits 35:34) must read as zero. */
  .text
  .globl test_main
test_main:
  csrr t0, mstatus
  csrw mstatus, t0          /* force a write so the register is updated */
  csrr t0, mstatus
  srli t0, t0, 34
  andi t0, t0, 3
  bnez t0, 1f
  PASS
1:
  FAIL(1)
