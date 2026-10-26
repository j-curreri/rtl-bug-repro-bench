#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* The RISC-V Privileged Specification defines CBIE (Cache Block Invalidation
   * Enable) as a 2-bit WARL field (bits 5:4) in the environment-configuration
   * registers (menvcfg, senvcfg, henvcfg).
   *
   * The legal values for CBIE are:
   *   2'b00: CBIE_ILLEGAL
   *   2'b01: CBIE_FLUSH
   *   2'b11: CBIE_INVAL
   * The value 2'b10 is reserved.
   *
   * By the WARL specification, a field must never hold an unsupported or
   * reserved value.
   *
   * On this buggy core, writing 2'b10 to CBIE sets the field to CBIE_RSVD (2'b10),
   * which can be read back. On a correct core, CBIE will not hold 2'b10.
   */

  /* Attempt to write reserved value 2'b10 into menvcfg.CBIE (bits 5:4) */
  csrr t0, menvcfg
  li t1, ~(3 << 4)
  and t0, t0, t1
  ori t0, t0, (2 << 4)
  csrw menvcfg, t0

  /* Read back menvcfg and isolate CBIE */
  csrr t2, menvcfg
  srli t2, t2, 4
  andi t2, t2, 3

  /* If CBIE holds the reserved value 2'b10 (2), this is the buggy core */
  li t3, 2
  beq t2, t3, 1f

  /* Correct core: ends with PASS */
  PASS

1:
  /* Buggy core: ends with FAIL */
  FAIL(1)
