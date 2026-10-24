/* repro.S — Reproducer for the menvcfg.CBIE WARL bug.
 *
 * Bug: The CBIE field of menvcfg (and senvcfg/henvcfg) is a WARL field. The
 *      buggy RTL maps the reserved encoding 2'b10 to CBIE_RSVD, so after
 *      software writes 2'b10 the field reads back the reserved value 2'b10.
 *      A WARL field must never read back a reserved value.
 *
 * This test writes menvcfg.CBIE = 2'b10, reads the register back, and fails
 * if the reserved encoding is observed.
 *   - Correct core : CBIE reads back a legal value (2'b00/01/11)  -> PASS
 *   - Buggy  core  : CBIE reads back the reserved 2'b10          -> FAIL
 *
 * In this core CBIE sits at menvcfg[5:4]. The reserved value 2'b10 is
 * (bit5=1, bit4=0) == 0x20; the field mask is 0x30.
 */

#include "test.h"

  .section .text
  .globl test_main

test_main:
  /* menvcfg is M-mode only, so no privilege/PMP setup is needed. */

  /* Write menvcfg.CBIE = 2'b10 (the reserved encoding). */
  li     t0, 0x20
  csrw   menvcfg, t0

  /* Read menvcfg back. Read-after-write of the same CSR is architecturally
   * guaranteed; a NOP simply lets the write settle one extra cycle. */
  nop
  csrr   t1, menvcfg

  /* Isolate the CBIE field: menvcfg[5:4]. */
  li     t2, 0x30
  and    t1, t1, t2

  /* If it read back the reserved 2'b10 (0x20), the WARL bug is present. */
  li     t2, 0x20
  bne    t1, t2, .Lcorrect
  FAIL(1)

.Lcorrect:
  PASS

/* Any trap means the test did not complete normally -> fail. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr   t6, mcause
  FAIL(127)
