#include "test.h"
#include "hyp.h"

  .text
  .globl test_main
test_main:
  csrw hgatp, zero
  /* MODE = 9 (Sv48x4, unsupported on this config), PPN = 0x80004 */
  li t0, (9 << 60) | 0x80004
  csrw hgatp, t0
  csrr t1, hgatp
  /* PPN field is WARL and must still be written */
  li t2, 0xfffffffffff
  and t3, t1, t2
  li t4, 0x80004
  bne t3, t4, fail
  /* MODE must hold a legal value (not 9) */
  srli t5, t1, 60
  li t6, 9
  beq t5, t6, fail
  csrw hgatp, zero
  PASS
fail:
  FAIL(1)
