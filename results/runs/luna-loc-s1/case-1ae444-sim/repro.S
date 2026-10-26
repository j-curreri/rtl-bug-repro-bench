#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Enable FIOM for the machine-controlled environment. */
  li t0, 1
  csrw menvcfg, t0

  /* Disable FIOM for the supervisor environment. This must not change menvcfg.FIOM. */
  li t0, 0
  csrw senvcfg, t0

  csrr t1, menvcfg
  andi t1, t1, 1
  li t2, 1
  bne t1, t2, fail

  PASS
fail:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  slli a0, t0, 1
  ori a0, a0, 1
  j _halt
