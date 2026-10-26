#include "test.h"

/* menvcfg.CBIE is bits [5:4]. Writing the reserved encoding 2'b10 is WARL:
 * the field must keep a legal value (the old one is fine) and never read back 2'b10. */
  .section .text
  .globl test_main
test_main:
  /* Write CBIE = 2'b10 (reserved), with all other menvcfg bits clear. */
  li t0, (2 << 4)
  csrw menvcfg, t0

  /* Read back and isolate CBIE. */
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, 1f
  PASS
1:
  FAIL(1)
