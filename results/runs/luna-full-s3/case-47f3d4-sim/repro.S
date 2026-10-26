#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* SXL is bits 35:34 of mstatus. With S-mode absent, it reads as zero. */
  csrr t0, mstatus
  srli t0, t0, 34
  andi t0, t0, 3
  bnez t0, fail_sxl

  PASS

fail_sxl:
  FAIL(1)
