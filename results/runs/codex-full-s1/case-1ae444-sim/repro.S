#include "test.h"

/*
 * The decoder keeps the interrupted instruction's bits in its exception tval.
 * A machine interrupt must nevertheless write zero to mtval.  Arrange for a
 * pending MSIP before enabling interrupts, then test mtval in the handler.
 */
  .section .text
  .option norvc
  .option norelax
  .balign 4
  .globl test_main
test_main:
  csrci mstatus, 8
  csrw mie, zero
  csrw mideleg, zero

  /* CLINT msip is a 32-bit register at base + 4 * hartid. */
  csrr t0, mhartid
  slli t0, t0, 2
  li s0, 0x02000000
  add s0, s0, t0
  li t0, 1
  sw t0, 0(s0)
  fence iorw, iorw

  /* Wait until the request has reached the core, with MIE still clear. */
1:
  csrr t0, mip
  andi t0, t0, 8
  beqz t0, 1b

  li t0, 8
  csrw mie, t0
  csrsi mstatus, 8

  /* Every instruction here has a nonzero encoding; no synchronous traps. */
2:
  addi t1, t1, 1
  j 2b

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 0x8000000000000003
  bne t0, t1, unexpected_trap
  csrr t2, mtval
  bnez t2, bad_mtval

  /* Quiesce the interrupt source before reporting success. */
  csrw mie, zero
  sw zero, 0(s0)
  fence iorw, iorw
  PASS

bad_mtval:
  FAIL(1)
unexpected_trap:
  FAIL(2)
