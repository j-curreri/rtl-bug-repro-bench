#include "test.h"

  .section .text
  .option norvc
  .balign 4
  .globl test_main
test_main:
  /* Keep interrupts disabled until a machine timer interrupt is pending. */
  csrci mstatus, 8
  csrw mie, zero
  csrw mideleg, zero

  /* CLINT mtimecmp[0] = 0: mtime is unsigned, so MTIP must assert. */
  li t0, 0x02004000
  sd zero, 0(t0)
  fence iorw, iorw

  li t0, 128                  /* mie.MTIE */
  csrw mie, t0
  li t1, 100000
1:
  csrr t2, mip
  andi t2, t2, 128
  bnez t2, 2f
  addi t1, t1, -1
  bnez t1, 1b
  FAIL(2)                     /* Timer did not become pending. */

2:
  csrw mtval, zero
  csrsi mstatus, 8            /* mstatus.MIE */
  /* All instructions here have nonzero encodings. The buggy decoder
     supplies an instruction encoding as the interrupt's trap value. */
3:
  addi t3, t3, 1
  j 3b

  .balign 4
  .globl trap_handler
trap_handler:
  /* Capture mtval before any CSR writes in the handler. */
  csrr t0, mtval
  csrr t1, mcause
  li t2, 0x8000000000000007  /* Machine timer interrupt. */
  bne t1, t2, unexpected_trap
  bnez t0, bad_mtval

  /* Deassert MTIP and leave interrupts disabled on the way to PASS. */
  csrw mie, zero
  li t1, 0x02004000
  li t2, -1
  sd t2, 0(t1)
  fence iorw, iorw
  PASS

bad_mtval:
  FAIL(1)
unexpected_trap:
  FAIL(3)
