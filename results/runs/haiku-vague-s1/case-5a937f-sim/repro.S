#include "test.h"

/*
 * menvcfg.CBIE (bits 5:4) is WARL. Value 2'b10 is reserved, so it must never
 * be readable back: a write of a reserved value must leave the field with a
 * legal value (the old one, or another legal one). This core stores the
 * reserved encoding CBIE_RSVD (2'b10) into the field.
 */
  .section .text
  .globl test_main
test_main:
  # Write CBIE = 2'b10 (reserved), everything else zero.
  li t0, 0x20
  csrw menvcfg, t0

  # Read back and check that the CBIE field does not hold the reserved value.
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, 1f

  PASS

1:
  FAIL(1)
