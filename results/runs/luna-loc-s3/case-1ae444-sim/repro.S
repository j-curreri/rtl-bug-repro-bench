#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Ask for big-endian accesses in M-mode only.  SBE and UBE are separate
     fields and remain zero in this write. */
  li t0, (1 << 37)
  csrs mstatus, t0
  csrr t1, mstatus

  /* If MBE is implemented, it must not make the untouched SBE/UBE fields
     appear enabled as a side effect.  An implementation with MBE=0 is
     allowed and has nothing to check. */
  srli t2, t1, 37
  andi t2, t2, 1
  beqz t2, 1f
  srli t2, t1, 36
  andi t2, t2, 1
  bnez t2, fail_sbe
  srli t2, t1, 6
  andi t2, t2, 1
  bnez t2, fail_ube
1:
  PASS

fail_sbe:
  FAIL(1)
fail_ube:
  FAIL(2)
