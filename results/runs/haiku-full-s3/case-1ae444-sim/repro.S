#include "test.h"

/* Reproducer: a machine-mode software interrupt must leave mtval zero. */
  .section .text.init
  .globl test_main
test_main:
  /* CLINT msip[0] = 1 raises a machine software interrupt. */
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)

  /* Enable MSIE in mie and MIE in mstatus; the interrupt is taken on the next instruction. */
  li t0, (1 << 3)
  csrs mie, t0
  csrsi mstatus, 0x8

  /* Bounded wait: a correct core takes the interrupt well before this runs out. */
  li t2, 1000
1:
  addi t2, t2, -1
  bnez t2, 1b
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  /* Expect exactly a machine software interrupt (mcause = interrupt bit | 3). */
  csrr t0, mcause
  li t1, ((1 << 63) | 3)
  bne t0, t1, 2f

  /* mtval must read as zero for interrupts. */
  csrr t0, mtval
  bnez t0, 3f

  /* Acknowledge the interrupt so the core can return to test_main. */
  li t0, 0x02000000
  sw zero, 0(t0)
  PASS

2:
  FAIL(3)
3:
  FAIL(4)
