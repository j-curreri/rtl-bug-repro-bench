/* Writing hgatp with an unsupported MODE is not ignored (unlike satp): the other fields are
 * still written and MODE keeps a legal value. */
#include "hyp.h"
  .text
  .globl test_main
test_main:
  csrw hgatp, zero
  li t0, (9 << 60) | 0x1234    /* MODE=9 (Sv48x4) is unsupported here */
  csrw hgatp, t0
  csrr t1, hgatp
  li t2, 0x1234
  bne t1, t2, 1f
  PASS
1: FAIL(1)
