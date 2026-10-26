#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* FIOM in HENVCFG and SENVCFG are independent architectural controls. */
  li t0, 1
  csrw henvcfg, t0
  csrw senvcfg, zero
  csrr t1, henvcfg
  andi t1, t1, 1
  li t2, 1
  bne t1, t2, fail
  PASS
fail:
  FAIL(3)

  .globl trap_handler
trap_handler:
  FAIL(4)
