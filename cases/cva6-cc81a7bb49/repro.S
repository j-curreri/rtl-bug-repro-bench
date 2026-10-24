/* menvcfg.CBIE (bits 5:4) is WARL; the reserved encoding 2'b10 must not be retained.
 * Write the legal value 01, then 10, and read back: the field must not read 10. */
#include "test.h"
  .text
  .globl test_main
test_main:
  li t0, (1 << 4)
  csrw menvcfg, t0
  li t0, (2 << 4)
  csrw menvcfg, t0
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, 1f
  PASS
1: FAIL(1)
