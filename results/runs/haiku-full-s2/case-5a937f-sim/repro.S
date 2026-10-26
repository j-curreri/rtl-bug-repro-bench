#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Establish a known legal CBIE value (INVAL = 2'b11) in menvcfg[5:4]. */
  li t0, 0x30
  csrw menvcfg, t0

  /* Write the reserved encoding 2'b10 to CBIE. WARL: the field must not hold it afterwards. */
  li t0, 0x20
  csrw menvcfg, t0

  /* Read back and extract CBIE. */
  csrr t0, menvcfg
  srli t0, t0, 4
  andi t0, t0, 3
  li t1, 2
  beq t0, t1, 1f

  PASS
1:
  FAIL(1)
