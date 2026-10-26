#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* mstatus.UBE (bit 6) is writable independently of MBE. */
  li t0, 0x40
  csrw mstatus, t0
  csrr t1, mstatus
  andi t1, t1, 0x40
  beqz t1, fail

  PASS

fail:
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr a0, mcause
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
