#include "test.h"

  .globl test_main
  .globl trap_handler

test_main:
  /* Set trap handler address */
  la t0, trap_handler
  csrw mtvec, t0

  /* Ensure mtval is 0 initially */
  csrw mtval, zero

  /* Enable machine software interrupt (MSIE is bit 3 of mie) */
  li t0, (1 << 3)
  csrs mie, t0

  /* Enable global interrupts in M-mode (MIE is bit 3 of mstatus) */
  csrsi mstatus, (1 << 3)

  /* Trigger software interrupt via CLINT msip register for hart 0 */
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)

  /* Loop waiting for the interrupt */
1:
  nop
  j 1b

  .align 2
trap_handler:
  /* Read trap cause and trap value immediately */
  csrr t1, mcause
  csrr t2, mtval

  /* Clear CLINT msip pending bit */
  li t0, 0x02000000
  sw zero, 0(t0)

  /* Verify this was indeed an interrupt (bit 63 of mcause must be 1) */
  bgez t1, unexpected_trap

  /* According to RISC-V privileged spec, mtval must be written with zero
   * when a machine-mode interrupt is taken.
   * If mtval != 0, we are on the buggy core. */
  bnez t2, buggy_core

  /* On a correct core, mtval is 0: test passes */
  PASS

buggy_core:
  FAIL(1)

unexpected_trap:
  FAIL(2)
