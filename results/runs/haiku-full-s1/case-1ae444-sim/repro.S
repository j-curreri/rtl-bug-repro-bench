#include "test.h"

/* Machine software interrupt via CLINT msip. The interrupt is injected at decode of the
 * instruction that follows the mstatus.MIE enable, so that instruction's bits are what the
 * buggy core leaves in mtval. The spec (and the task) require mtval to read zero here. */
#define CLINT_MSIP 0x02000000

  .section .text
  .globl test_main
test_main:
  /* raise a machine software interrupt request, then enable MSIE and MIE */
  li t0, CLINT_MSIP
  li t1, 1
  sw t1, 0(t0)
  li t0, (1 << 3)
  csrs mie, t0
  csrsi mstatus, 0x8

  /* the interrupt is taken within these instructions; reaching the end means it never came */
  .rept 64
  nop
  .endr
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  bgez t0, 1f           /* not an interrupt: fail */
  li t1, ((1 << 63) | 3)
  bne t0, t1, 1f        /* expect machine software interrupt */
  csrr t0, mtval
  bnez t0, 2f           /* mtval must be zero for interrupts */
  li t0, CLINT_MSIP
  sw zero, 0(t0)        /* clear the request so we do not re-enter */
  PASS
1:
  FAIL(3)
2:
  FAIL(4)
