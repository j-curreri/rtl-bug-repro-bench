#include "test.h"

  .section .text
  .globl test_main
test_main:
  li t0, 1
  csrs senvcfg, t0

  /* SENVCFG.FIOM must not change the independent MENVCFG.FIOM field. */
  csrr t0, menvcfg
  andi t0, t0, 1
  bnez t0, fail_shared_fiom
  PASS

fail_shared_fiom:
  FAIL(1)

  .globl trap_handler
trap_handler:
  FAIL(127)

