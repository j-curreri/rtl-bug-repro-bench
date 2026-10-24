#include "test.h"

/* Write the reserved CBIE encoding (2'b10) into menvcfg/senvcfg.CBIE (bits 5:4).
 * CBIE is WARL, so it must never read back as 2'b10. */
  .text
  .globl test_main
test_main:
  /* menvcfg: start from a legal value (11), then write reserved 10 */
  li t0, 0x30
  csrw menvcfg, t0
  li t0, 0x20
  csrw menvcfg, t0
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, fail_m

  /* menvcfg: from 00 */
  csrw menvcfg, zero
  li t0, 0x20
  csrs menvcfg, t0
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  beq t1, t2, fail_m

  /* senvcfg */
  li t0, 0x30
  csrw senvcfg, t0
  li t0, 0x20
  csrw senvcfg, t0
  csrr t1, senvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  beq t1, t2, fail_s

  PASS
fail_m:
  FAIL(1)
fail_s:
  FAIL(2)
