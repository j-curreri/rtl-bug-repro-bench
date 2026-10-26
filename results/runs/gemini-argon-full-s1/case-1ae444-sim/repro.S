#include "test.h"

  .text
  .globl test_main
test_main:
  /* Initialize interrupt-handled flag and loop counter */
  li s0, 0
  li s1, 10000

  /* Pre-load mtval with a non-zero value; taking an M-mode interrupt must
   * write zero to mtval according to the RISC-V Privileged Specification. */
  li t0, 0xdeadbeef
  csrw mtval, t0

  /* Ensure M-mode interrupts are globally disabled during setup */
  csrci mstatus, 8

  /* Enable Machine Software Interrupt (MSIE, bit 3) */
  li t0, (1 << 3)
  csrw mie, t0

  /* Trigger Machine Software Interrupt for hart 0 via CLINT MSIP (0x02000000) */
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)
  fence iorw, iorw

  /* Enable M-mode interrupts globally (mstatus.MIE, bit 3) */
  csrsi mstatus, 8

1:
  bnez s0, 2f
  addi s1, s1, -1
  bnez s1, 1b
  bnez s0, 2f

  /* Timed out waiting for interrupt */
  FAIL(3)

2:
  PASS

  .globl trap_handler
  .balign 64
trap_handler:
  /* Verify trap is Machine Software Interrupt: mcause == (1 << 63) | 3 */
  csrr t1, mcause
  li t2, 1
  slli t2, t2, 63
  ori t2, t2, 3
  bne t1, t2, unexpected_trap

  /* Privileged spec: mtval is written with zero on M-mode interrupts */
  csrr t3, mtval
  bnez t3, mtval_nonzero

  /* Clear CLINT MSIP and disable MSIE before returning */
  li t0, 0x02000000
  sw zero, 0(t0)
  csrw mie, zero
  fence iorw, iorw

  /* Signal completion and return from interrupt */
  li s0, 1
  mret

mtval_nonzero:
  FAIL(1)

unexpected_trap:
  FAIL(2)
