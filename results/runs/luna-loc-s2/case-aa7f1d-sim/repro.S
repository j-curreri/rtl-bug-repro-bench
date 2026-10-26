#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* FIOM is independently WARL in menvcfg and henvcfg. */
  li t0, 1
  csrw menvcfg, t0
  li t0, 0
  csrw henvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 1
  li t2, 1
  bne t1, t2, fail

  PASS
fail:
  FAIL(1)

  .globl trap_handler
trap_handler:
  FAIL(2)
