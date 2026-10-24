#include "test.h"

/* mstatus.SXL (bits 35:34) must be read-only zero when S-mode is not implemented. */
  .text
  .globl test_main
test_main:
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  bnez t1, fail1

  /* attempt to set SXL; it must stay zero */
  li t0, (3 << 34)
  csrs mstatus, t0
  csrr t1, mstatus
  srli t1, t1, 34
  andi t1, t1, 3
  bnez t1, fail2

  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
