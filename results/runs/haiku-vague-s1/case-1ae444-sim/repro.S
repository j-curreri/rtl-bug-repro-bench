#include "test.h"

/* Reproducer: an asynchronous machine timer interrupt must leave mtval at zero.
 * The spec only lets mtval carry exception-specific information; an interrupt has none,
 * so mtval is zero. This core's decoder forwards the instruction bits as tval for
 * interrupts, so mtval comes back nonzero and the handler fails. */

#define CLINT_MTIMECMP 0x02004000

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* mtimecmp = 0 so the machine timer interrupt is pending immediately */
  li t0, CLINT_MTIMECMP
  sd zero, 0(t0)
  /* enable MTIE and global MIE */
  li t0, (1 << 7)
  csrs mie, t0
  li t0, (1 << 3)
  csrs mstatus, t0

  /* spin on nonzero instructions (addi x0,x0,0 encodes as 0x00000013) until the interrupt arrives */
  li t1, 1000
1:
  addi t1, t1, -1
  nop
  bnez t1, 1b
  /* no interrupt was taken in time */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  bgez t0, 2f                 /* must be an interrupt */
  li t1, ((1 << 63) | 7)      /* machine timer interrupt */
  bne t0, t1, 3f
  csrr t0, mtval
  bnez t0, 4f                 /* mtval must be zero for an interrupt */
  /* acknowledge: push mtimecmp far away so the interrupt does not refire */
  li t1, CLINT_MTIMECMP
  li t2, -1
  sd t2, 0(t1)
  PASS

2:
  FAIL(2)
3:
  FAIL(3)
4:
  FAIL(4)
