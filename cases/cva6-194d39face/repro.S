/* mtval must be zero after an interrupt trap. Uses a CLINT machine software interrupt. */
#include "test.h"
#define CLINT_MSIP 0x02000000
  .text
  .globl test_main
test_main:
  li t0, 0x5a5a5a5a
  csrw mtval, t0
  li t0, (1 << 3)              /* mie.MSIE */
  csrs mie, t0
  csrsi mstatus, 8             /* mstatus.MIE */
  li t0, CLINT_MSIP
  li t1, 1
  sw t1, 0(t0)
1: j 1b                        /* wait for the interrupt */

  .align 2
  .globl trap_handler
trap_handler:
  li t0, CLINT_MSIP
  sw zero, 0(t0)
  csrr t0, mcause
  li t1, (1 << 63) | 3
  bne t0, t1, 1f
  csrr t0, mtval
  bnez t0, 2f
  PASS
1: FAIL(1)
2: FAIL(2)
