#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* menvcfg.CBIE is bits [5:4]. Encoding 0b10 is reserved, so a
   * conforming WARL implementation must return one of 00, 01, or 11.
   * Do not require any particular choice among those legal encodings.
   */
  li t0, 0x20
  csrw 0x30a, t0               /* menvcfg: attempt CBIE = 0b10 */
  csrr t1, 0x30a
  andi t1, t1, 0x30           /* isolate CBIE */
  beq t1, t0, reserved_readback
  PASS

reserved_readback:
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  /* All accesses above are legal in M-mode; any trap is unexpected. */
  csrr t6, mcause
  FAIL(2)
