#include "test.h"

#define CLINT_MSIP 0x02000000

  .text
  .globl test_main
test_main:
  li s0, 0                      /* interrupt-taken flag */
  li t0, 0x12345678
  csrw mtval, t0                /* make stale mtval nonzero */
  li t0, (1 << 3)               /* mie.MSIE */
  csrw mie, t0
  li t1, CLINT_MSIP
  li t0, 1
  sw t0, 0(t1)                  /* raise machine software interrupt */
  csrsi mstatus, 8              /* mstatus.MIE */
  li t2, 10000
1:
  bnez s0, 2f
  addi t2, t2, -1
  bnez t2, 1b
  FAIL(1)                       /* interrupt never taken */
2:
  csrci mstatus, 8
  li t0, 2
  bne s0, t0, 3f
  PASS
3:
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t3, mcause
  csrr t4, mtval
  li t5, CLINT_MSIP
  sw zero, 0(t5)                /* clear MSIP */
  li t5, (1 << 63) | 3
  bne t3, t5, bad_cause
  li s0, 1
  bnez t4, 4f
  li s0, 2                      /* mtval was zero: correct */
4:
  csrw mie, zero
  mret
bad_cause:
  FAIL(3)
