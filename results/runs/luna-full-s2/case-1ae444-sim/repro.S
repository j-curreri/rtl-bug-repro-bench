#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Start with the timer safely disabled, and give mtval a stale value. */
  li t0, 0x02004000          /* CLINT mtimecmp */
  li t1, -1
  sd t1, 0(t0)

  li t1, 0x13579bdf
  csrw mtval, t1

  /* Enable machine timer interrupts, then make one immediately pending. */
  li t0, (1 << 7)
  csrs mie, t0
  li t0, (1 << 3)
  csrs mstatus, t0

  li t0, 0x02004000
  sd zero, 0(t0)
1:
  wfi
  j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  bltz t0, .Linterrupt
  /* A synchronous or otherwise unexpected trap is not part of this test. */
  FAIL(1)

.Linterrupt:
  /* Avoid taking the still-pending timer interrupt again. */
  li t0, (1 << 7)
  csrc mie, t0

  csrr t1, mtval
  bnez t1, .Lbad_mtval
  PASS

.Lbad_mtval:
  FAIL(2)
