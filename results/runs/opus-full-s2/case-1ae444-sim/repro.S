#include "test.h"

  .text
  .globl test_main
test_main:
  li t0, 0x12345678
  csrw mtval, t0          /* stale nonzero value: interrupt must overwrite with 0 */
  li t0, (1 << 3)         /* MSIE */
  csrw mie, t0
  li t1, 0x02000000       /* CLINT msip */
  li t0, 1
  sw t0, 0(t1)
  csrsi mstatus, 8        /* MIE */
  li t2, 0
1:
  addi t2, t2, 1
  li t3, 100000
  blt t2, t3, 1b
  FAIL(1)                 /* interrupt never taken */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t4, mcause
  li t5, 0x8000000000000003
  bne t4, t5, bad_cause
  csrr t4, mtval
  bnez t4, bad_tval
  li t1, 0x02000000
  sw zero, 0(t1)
  PASS
bad_cause:
  FAIL(2)
bad_tval:
  FAIL(3)
