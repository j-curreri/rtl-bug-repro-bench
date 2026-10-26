#include "test.h"

/* Raise a machine software interrupt via CLINT msip and check that mtval reads zero
 * in the trap handler. The interrupt is taken at decode of a real instruction, whose
 * encoding is non-zero, so the buggy core leaks that encoding into mtval. */

  .section .text
  .globl test_main
test_main:
  /* Set msip[hart 0] = 1 to make a machine software interrupt pending. */
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)
  fence

  /* Enable MSIE in mie and the global MIE bit in mstatus. */
  li t0, (1 << 3)
  csrs mie, t0
  csrsi mstatus, 0x8

  /* The interrupt should be taken within a few instructions. */
  .rept 16
  nop
  .endr

  /* Not reached on a correct core if the interrupt was taken: the handler ends the test. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  bgez t0, 1f          /* not an interrupt: fail */
  csrr t1, mtval
  bnez t1, 2f          /* interrupt with nonzero mtval: fail */
  PASS
1:
  FAIL(2)
2:
  FAIL(3)
