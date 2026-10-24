#include "test.h"
/* menvcfg/senvcfg/henvcfg.CBIE is WARL; the encoding 0b10 is reserved and
 * must never be read back. Write it and check that it does not stick. */
  .text
  .globl test_main
test_main:
  li t1, 0x30          /* CBIE mask */
  li t2, 0x20          /* reserved CBIE = 0b10 */

  csrw 0x30a, t2       /* menvcfg */
  csrr t0, 0x30a
  and t0, t0, t1
  beq t0, t2, fail1

  csrw 0x10a, t2       /* senvcfg */
  csrr t0, 0x10a
  and t0, t0, t1
  beq t0, t2, fail2

  csrw 0x60a, t2       /* henvcfg */
  csrr t0, 0x60a
  and t0, t0, t1
  beq t0, t2, fail3

  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
fail3:
  FAIL(3)
