/* hgatp bits 59:58 are a read-only-zero (WARL 0) field in RV64. The buggy core
 * stores whatever is written there; a correct core always reads them back as 0. */
#include "test.h"
.text
.globl test_main
test_main:
  csrw hgatp, zero
  /* MODE=Bare, bits 59:58 set */
  li t0, (3 << 58)
  csrw hgatp, t0
  csrr t1, hgatp
  srli t1, t1, 58
  andi t1, t1, 3
  bnez t1, fail1
  /* MODE=Sv39x4, bits 59:58 set, VMID/PPN zero */
  li t0, (8 << 60) | (3 << 58)
  csrw hgatp, t0
  csrr t1, hgatp
  csrw hgatp, zero
  srli t1, t1, 58
  andi t1, t1, 3
  bnez t1, fail2
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
