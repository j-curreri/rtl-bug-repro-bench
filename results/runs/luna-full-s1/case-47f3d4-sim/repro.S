#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* SXL occupies mstatus[35:34] on RV64. With S-mode unimplemented,
     this field is WARL and must read as zero. */
  csrr t0, mstatus
  srli t0, t0, 34
  andi t0, t0, 3
  bnez t0, fail_sxl

  PASS

fail_sxl:
  FAIL(1)
