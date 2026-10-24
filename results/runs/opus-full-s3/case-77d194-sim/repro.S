#include "test.h"

/* Writing hgatp with an unsupported MODE must still update the other WARL fields
 * (unlike satp, where such a write is ignored entirely). */
  .text
  .globl test_main
test_main:
  csrw hgatp, zero
  /* MODE = 15 (reserved/unsupported), PPN = 0x1000 */
  li t0, (15 << 60) | 0x1000
  csrw hgatp, t0
  csrr t1, hgatp
  /* PPN field (bits 43:0) should now hold 0x1000 */
  li t2, 0xfffffffffff
  and t3, t1, t2
  li t4, 0x1000
  bne t3, t4, fail
  /* MODE must be a legal value: Bare (0) or Sv39x4 (8) */
  srli t5, t1, 60
  beqz t5, ok
  li t6, 8
  bne t5, t6, fail
ok:
  csrw hgatp, zero
  PASS
fail:
  FAIL(1)
