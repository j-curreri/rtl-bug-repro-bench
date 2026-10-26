#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Arrange a real synchronous trap so a nonzero trap value is live. */
  li t0, 0x02004000           /* CLINT mtimecmp */
  li t1, -1
  sd t1, 0(t0)
  li t0, (1 << 7)              /* MTIE */
  csrs mie, t0
  li t0, (1 << 3)              /* MSTATUS.MIE */
  csrs mstatus, t0
  li t0, 1
  lw t1, 0(t0)                 /* load address misaligned: mtval = 1 */
1: j 1b

  .align 2
  .globl trap_handler
trap_handler:
  csrr t2, mcause
  li t3, 4                     /* load address misaligned */
  beq t2, t3, 3f

  /* The nested machine timer interrupt must clear the previous mtval. */
  csrr t0, mtval
  li t1, 0x02004000
  li t2, -1
  sd t2, 0(t1)
  bnez t0, 2f
  PASS
2:
  FAIL(1)
3:
  /* Keep handling in M-mode, then take a nested interrupt. */
  li t0, 0x02004000
  sd zero, 0(t0)
  li t0, (1 << 3)
  csrs mstatus, t0
4: j 4b
