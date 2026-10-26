#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* menvcfg.CBIE is bits [5:4]. 2'b10 is reserved and WARL. */
  li t0, 0x20
  csrw menvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 0x30

  /* A legal readback is 00, 01, or 11; retaining 10 is the bug. */
  li t2, 0x20
  beq t1, t2, fail_reserved_cbie
  PASS

fail_reserved_cbie:
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  /* Any trap is unexpected for this M-mode CSR check. */
  FAIL(127)
