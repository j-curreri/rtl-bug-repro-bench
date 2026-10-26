#include "test.h"

/* Bug: on an interrupt, mtval holds the bits of the instruction being decoded
 * instead of zero. Take a machine software interrupt (CLINT msip) while nops
 * execute and check that mtval is 0 in the handler. */

  .section .text
  .globl test_main
test_main:
  li t0, (1 << 3)          # mie.MSIE
  csrw mie, t0
  csrsi mstatus, 8         # mstatus.MIE
  li t0, 0x02000000        # CLINT msip[hart 0]
  li t1, 1
  sw t1, 0(t0)             # raise machine software interrupt

  .rept 32
  nop
  .endr
  FAIL(2)                  # interrupt was never taken

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, ((1 << 63) | 3)  # machine software interrupt
  bne t6, t5, 1f
  csrr t6, mtval
  bnez t6, 2f              # interrupts must leave mtval zero
  li t1, 0x02000000
  sw zero, 0(t1)           # clear msip
  PASS
1: FAIL(3)                 # unexpected cause
2: FAIL(1)                 # mtval not zero on interrupt
