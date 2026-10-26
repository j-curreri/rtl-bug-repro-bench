  #include "test.h"

  .section .text
  .globl test_main
  .align 2
test_main:
  /* SENVCFG.FIOM is independent of MENVCFG.FIOM. */
  li t0, 1
  csrw senvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 1
  bnez t1, fail_shared_fiom
  PASS

fail_shared_fiom:
  FAIL(1)
