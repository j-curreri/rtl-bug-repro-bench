#include "test.h"

/* Write the reserved CBIE encoding 2'b10 (bits 5:4) to menvcfg and senvcfg.
 * CBIE is WARL: the value read back must never be the reserved 2'b10. */
  .text
  .globl test_main
test_main:
  /* menvcfg (0x30A) */
  li t0, 0x20
  csrw 0x30A, t0
  csrr t1, 0x30A
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, fail_m

  /* senvcfg (0x10A) */
  li t0, 0x20
  csrw 0x10A, t0
  csrr t1, 0x10A
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, fail_s

  PASS
fail_m:
  FAIL(1)
fail_s:
  FAIL(2)
