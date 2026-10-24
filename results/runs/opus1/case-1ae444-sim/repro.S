#include "test.h"

#define CLINT_MSIP 0x02000000

  .text
  .globl test_main
test_main:
  li s0, 0                 /* interrupt count */
  /* make mtval nonzero so a stale value would also be caught */
  li t0, -1
  csrw mtval, t0
  li t0, (1 << 3)          /* MSIE */
  csrw mie, t0
  li t1, CLINT_MSIP
  li t0, 1
  sw t0, 0(t1)
  csrsi mstatus, 8         /* MIE */
  /* run some ordinary instructions; interrupt arrives on one of them */
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
  addi a1, a1, 1
1:
  beqz s0, 1b
  csrci mstatus, 8
  li t0, 1
  bne s0, t0, fail_count
  bnez s1, fail_tval
  PASS
fail_count:
  FAIL(2)
fail_tval:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t2, mcause
  bgez t2, unexpected
  csrr s1, mtval
  li t1, CLINT_MSIP
  sw zero, 0(t1)
  csrw mie, zero           /* no re-entry even if the CLINT write lags */
  addi s0, s0, 1
  mret
unexpected:
  FAIL(3)
