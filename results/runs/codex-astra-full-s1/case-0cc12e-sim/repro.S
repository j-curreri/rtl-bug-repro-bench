#include "test.h"

  .section .text
  .option norvc
  .balign 4
  .globl test_main
test_main:
  /* Keep the test entirely in M-mode, with interrupts disabled. */
  csrci mstatus, 8
  csrw mie, zero
  la t0, trap_handler
  csrw mtvec, t0

  /* ECALL must overwrite mtval with zero, regardless of its old value. */
  li t0, 0x1234
  csrw mtval, t0
  la s0, ecall_site
ecall_site:
  ecall
  FAIL(1)                       /* ECALL must trap. */

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11                     /* Environment call from M-mode. */
  bne t0, t1, wrong_cause
  csrr t0, mepc
  bne t0, s0, wrong_pc
  csrr t0, mtval
  bnez t0, wrong_tval
  PASS

wrong_cause:
  FAIL(2)
wrong_pc:
  FAIL(3)
wrong_tval:
  FAIL(4)
