#include "test.h"

/* hgatp fields are WARL even when MODE is unsupported: writing an unsupported
 * MODE must not cause the whole write (PPN, VMID) to be dropped. */
  .text
  .globl test_main
test_main:
  csrw hgatp, zero
  csrr t0, hgatp
  bnez t0, fail1

  /* MODE = 1 (reserved/unsupported), PPN = 0x80010 */
  li t0, (1 << 60) | 0x80010
  csrw hgatp, t0
  csrr t1, hgatp

  /* PPN field is bits [43:0] */
  slli t1, t1, 20
  srli t1, t1, 20
  li t2, 0x80010
  bne t1, t2, fail2

  csrw hgatp, zero
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
