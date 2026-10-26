#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* SXL is reserved and reads as zero when S-mode is not implemented. */
  csrr t0, mstatus
  srli t0, t0, 34
  andi t0, t0, 3
  bnez t0, fail
  PASS

fail:
  FAIL(1)

  .globl trap_handler
trap_handler:
  FAIL(127)
