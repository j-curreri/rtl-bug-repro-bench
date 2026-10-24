#include "test.h"

/* Write the reserved CBIE encoding 2'b10 into menvcfg/senvcfg (WARL);
 * the read-back value must never be the reserved encoding. */
  .text
  .globl test_main
test_main:
  li   t1, 0x30          /* CBIE field mask, bits [5:4] */
  li   t2, 0x20          /* reserved encoding 2'b10 */

  csrs menvcfg, t2
  csrc menvcfg, t1
  csrs menvcfg, t2       /* explicit write of 0b10 into CBIE */
  csrr t0, menvcfg
  and  t0, t0, t1
  beq  t0, t2, fail_m

  csrw menvcfg, t2
  csrr t0, menvcfg
  and  t0, t0, t1
  beq  t0, t2, fail_m

  csrw senvcfg, t2
  csrr t0, senvcfg
  and  t0, t0, t1
  beq  t0, t2, fail_s

  PASS
fail_m:
  FAIL(1)
fail_s:
  FAIL(2)
