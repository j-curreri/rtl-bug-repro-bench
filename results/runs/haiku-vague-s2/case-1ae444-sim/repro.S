/* Bug: an interrupt leaves a nonzero value in mtval. The privileged spec says mtval is
 * either zero or exception-specific information, and an asynchronous interrupt has no
 * faulting instruction, so mtval must be zero. A timer interrupt is taken here and
 * the handler checks mtval. */
#include "test.h"

#define MTIMECMP 0x02004000
#define MTIME    0x0200BFF8
#define MTIMER_IRQ_CAUSE 0x8000000000000007

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* mtimecmp = mtime + 200 so a machine timer interrupt fires shortly */
  li t0, MTIME
  ld t1, 0(t0)
  addi t1, t1, 200
  li t0, MTIMECMP
  sd t1, 0(t0)
  /* enable machine timer interrupts globally */
  li t0, (1 << 7)
  csrs mie, t0
  csrsi mstatus, 8

  /* spin until the interrupt has been taken and handled */
  li s0, 0
1: addi s0, s0, 1
  li t3, 100000
  blt s0, t3, 1b
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, MTIMER_IRQ_CAUSE
  bne t0, t1, 3f
  /* mtval must be zero on an interrupt */
  csrr t0, mtval
  bnez t0, 4f
  /* disarm the timer so the interrupt does not fire again */
  li t0, MTIMECMP
  li t1, -1
  sd t1, 0(t0)
  mret
3: FAIL(3)
4: FAIL(4)
