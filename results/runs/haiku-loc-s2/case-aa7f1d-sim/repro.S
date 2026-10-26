#include "test.h"

/* Spec: U-mode access to a counter needs both mcounteren[n] and scounteren[n] set,
 * otherwise it raises illegal instruction. Here mcounteren[0]=1 and scounteren[0]=0,
 * so the cycle read in U-mode must trap. The buggy core lets it through. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, 1
  csrw mcounteren, t0
  csrw scounteren, zero
  ENTER_MODE(0, user_code)

  .align 2
user_code:
  csrr a1, cycle
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 2
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
