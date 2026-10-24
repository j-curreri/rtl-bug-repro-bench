#include "test.h"

/* Bug: the CBIE field (bits 5:4) of menvcfg/senvcfg is WARL and 2'b10 is a
 * reserved encoding, so it must never be held. Write CBIE=0b10 into menvcfg and
 * senvcfg (this config has no H extension) and read it back. The buggy core
 * keeps the reserved value in both; a correct core legalizes it. */

  .text
  .globl test_main
test_main:
  li   s0, 0              /* count of CSRs holding the reserved CBIE value */
  li   t1, 0x20           /* CBIE = 2'b10 */
  li   t3, 0x30

  csrw menvcfg, t1
  csrr t2, menvcfg
  and  t2, t2, t3
  bne  t2, t1, 1f
  addi s0, s0, 1
1:
  csrw senvcfg, t1
  csrr t2, senvcfg
  and  t2, t2, t3
  bne  t2, t1, 2f
  addi s0, s0, 1
2:

  li   t0, 2
  beq  s0, t0, fail
  PASS
fail:
  FAIL(1)
