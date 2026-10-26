#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* HENVCFG.FIOM is separate from MENVCFG.FIOM. */
  csrw 0x30a, zero
  li t0, 1
  csrw 0x60a, t0
  csrr t1, 0x60a
  andi t1, t1, 1
  beqz t1, fail
  csrr t1, 0x30a
  andi t1, t1, 1
  bnez t1, fail
  PASS
fail:
  FAIL(1)
