#include "test.h"

  .text
  .global test_main
test_main:
  csrw hgatp, zero
  /* MODE = 9 (Sv48x4, unsupported on this Sv39 core), PPN = 0x80010 */
  li t0, (9 << 60) | 0x80010
  csrw hgatp, t0
  csrr t1, hgatp
  /* PPN field must be written (WARL in the normal way) */
  li t2, 0xFFFFFFFFFFF
  and t1, t1, t2
  li t3, 0x80010
  bne t1, t3, 1f
  PASS
1:
  FAIL(1)
