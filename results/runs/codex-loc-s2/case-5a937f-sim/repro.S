#include "test.h"

/* menvcfg.FIOM and senvcfg.FIOM govern different privilege modes and
 * are independent state.  Updating senvcfg must not change menvcfg.
 */
  .section .text
  .globl test_main
test_main:
  csrw menvcfg, zero
  csrw senvcfg, zero
  li t0, 1
  csrw senvcfg, t0
  csrr t1, menvcfg
  andi t1, t1, 1
  bnez t1, bad_alias
  PASS

bad_alias:
  FAIL(1)

  .balign 4
  .globl trap_handler
trap_handler:
  FAIL(127)
