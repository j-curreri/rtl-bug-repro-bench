#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* menvcfg (0x30a), CBIE = bits [5:4]. Start from a legal value. */
  csrw 0x30a, zero

  /* CBIE=10 is reserved. A WARL field must read back a legal encoding,
   * but the implementation may choose any of 00, 01, or 11.
   */
  li t0, 0x20
  csrw 0x30a, t0
  csrr t1, 0x30a
  andi t1, t1, 0x30
  beq t1, t0, reserved_cbie
  PASS

reserved_cbie:
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(127)
