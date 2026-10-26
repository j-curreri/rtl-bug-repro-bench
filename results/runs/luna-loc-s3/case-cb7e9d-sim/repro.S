#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Set trigger 0 to an execute-address NAPOT match.  A one-bit NAPOT
     encoding covers the four-byte word starting at target. */
  csrw tselect, zero
  la t0, target
  ori t0, t0, 1
  csrw tdata2, t0
  li t0, 0x60000000000000c4  /* type=6, match=NAPOT, M, execute */
  csrw tdata1, t0

  la t0, actual
  jr t0

  .align 5
target:
  .2byte 0x0001                /* compressed nop at target */
actual:
  nop                          /* target + 2 is in the NAPOT word */
  FAIL(2)                      /* reached if the trigger fails to match */

  .globl trap_handler
trap_handler:
  /* The NAPOT range includes actual, so a trap is the expected result. */
  PASS
