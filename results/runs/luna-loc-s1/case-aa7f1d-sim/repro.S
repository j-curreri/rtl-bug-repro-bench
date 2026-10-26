#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* FIOM in henvcfg configures guest execution and must not alias menvcfg. */
  li t0, 1
  csrw menvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 1
  beqz t1, fail

  /* Clearing the guest setting must leave the machine setting unchanged. */
  csrw henvcfg, zero
  csrr t1, menvcfg
  andi t1, t1, 1
  beqz t1, fail

  PASS
fail:
  FAIL(1)
