#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* SXL is bits 35:34. This M/U-only RV64 implementation must keep it zero. */
  li t0, (2 << 34)              /* SXL=2 denotes RV64. */
  csrw mstatus, t0
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  bnez t1, fail_sxl

  PASS

fail_sxl:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(127)
