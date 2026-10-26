#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* FIOM is a separate WARL bit in MENVCFG and HENVCFG. */
  csrw menvcfg, zero
  csrw henvcfg, zero

  li t0, 1
  csrw menvcfg, t0
  csrr t1, henvcfg
  andi t1, t1, 1
  bnez t1, fail

  csrw henvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 1
  beqz t1, fail

  csrr t1, henvcfg
  andi t1, t1, 1
  beqz t1, fail

  PASS

fail:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(2)
