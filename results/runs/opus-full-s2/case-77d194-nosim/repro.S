#include "test.h"

  .text
  .globl test_main
test_main:
  /* Start from a known state: Bare mode, PPN = 0. */
  csrw hgatp, zero
  csrr t0, hgatp
  bnez t0, fail1

  /* Write MODE = 9 (Sv48x4, unsupported on Sv39 config) with a nonzero PPN.
   * Per the H spec the write is not ignored; PPN is WARL normally. */
  li t1, (9 << 60)
  li t2, 0x80004
  or t1, t1, t2
  csrw hgatp, t1
  csrr t0, hgatp

  /* PPN field (bits 43:0) must have taken the written value. */
  slli t3, t0, 20
  srli t3, t3, 20
  bne t3, t2, fail2

  /* MODE must hold a legal value (Bare or Sv39x4), never 9. */
  srli t4, t0, 60
  li t5, 9
  beq t4, t5, fail3

  csrw hgatp, zero
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)
