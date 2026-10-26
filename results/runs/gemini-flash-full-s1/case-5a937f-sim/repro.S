#include "test.h"

  .globl test_main
test_main:
  /*
   * Bug report:
   * The CBIE field of menvcfg (and senvcfg/henvcfg) can be left holding
   * the reserved encoding 2'b10 after software writes it. The field is
   * WARL and must never read back a reserved value.
   *
   * CBIE occupies bits [5:4] of menvcfg.
   * Reserved encoding is 2'b10 (0x20).
   */

  /* Test 1: Set CBIE to 2'b00, then attempt to write reserved 2'b10 */
  li   t0, 0x30
  csrc menvcfg, t0       /* CBIE = 2'b00 */
  li   t0, 0x20
  csrs menvcfg, t0       /* Attempt to write CBIE = 2'b10 */
  csrr t1, menvcfg
  andi t1, t1, 0x30
  li   t2, 0x20
  beq  t1, t2, fail      /* Reserved encoding 2'b10 read back -> bug! */

  /* Test 2: Set CBIE to 2'b11, then attempt to write reserved 2'b10 */
  li   t0, 0x30
  csrs menvcfg, t0       /* CBIE = 2'b11 */
  li   t0, 0x10
  csrc menvcfg, t0       /* Attempt to write CBIE = 2'b10 */
  csrr t1, menvcfg
  andi t1, t1, 0x30
  beq  t1, t2, fail      /* Reserved encoding 2'b10 read back -> bug! */

  /* On a correct core, CBIE will never read back 2'b10 */
  PASS

fail:
  FAIL(1)
