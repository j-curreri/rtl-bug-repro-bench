#include "harness/test.h"

  .section .text
  .globl test_main
test_main:
  /* Enable the parent FIOM field before testing its independently stored
   * subordinate fields. */
  li t0, 1
  csrw menvcfg, t0

  /* FIOM is a separate WARL field in each environment-configuration CSR. */
  li t0, 0
  csrw senvcfg, t0
  csrw henvcfg, t0

  /* Changing HENVCFG.FIOM must not change SENVCFG.FIOM. */
  li t0, 1
  csrw henvcfg, t0
  csrr t1, senvcfg
  andi t1, t1, 1
  bnez t1, fail

  PASS
fail:
  FAIL(1)
