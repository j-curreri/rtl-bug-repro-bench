#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /*
   * Entry 1 is a no-permission TOR region starting at zero.  Give it an
   * upper bound of _start + 4.  Since _start is 8-byte aligned, this makes
   * pmpaddr1[0] one.  With G=1 the architectural TOR bound is rounded down
   * to _start; the buggy implementation compares against the raw bound.
   * Entry 2 permits all addresses that entry 1 does not match.
   */
  csrw pmpaddr0, zero
  li t0, 0x20000001          /* (0x80000000 + 4) >> 2 */
  csrw pmpaddr1, t0
  li t0, -1
  csrw pmpaddr2, t0
  li t0, 0x001f0800          /* entry 1: TOR, deny; entry 2: NAPOT, RWX */
  csrw pmpcfg0, t0

  ENTER_MODE(0, user_test)

  .align 2
user_test:
  /* At the rounded TOR boundary, this must fall through to entry 2. */
  la t0, _start
  ld t1, 0(t0)
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  /* The load access fault is the expected symptom on the buggy core. */
  FAIL(2)
