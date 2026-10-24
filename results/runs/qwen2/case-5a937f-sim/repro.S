/* Repro for: menvcfg.CBIE (and senvcfg/henvcfg.CBIE) WARL violation.
 *
 * menvcfg[5:4] (CBIE) is WARL: an implementation must never read back the
 * reserved encoding 2'b10. This core stores the reserved value when software
 * writes it, so reading menvcfg back after such a write returns 2'b10 in
 * [5:4]. A spec-conforming core maps the write to an implemented value, so
 * the read-back is never 2'b10.
 *
 * Correct core: PASS.  Buggy core: FAIL(1).
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  li t0, 2
  slli t0, t0, 4          /* t0 = 0x20: menvcfg.CBIE = 2'b10 (reserved) */
  csrw menvcfg, t0
  csrr t1, menvcfg
  srli t1, t1, 4
  andi t1, t1, 3
  li t2, 2
  beq t1, t2, fail        /* read back a reserved value: buggy core */
  PASS

fail:
  FAIL(1)
