#include "test.h"

/* Privileged spec: mtval is zero after ECALL and EBREAK (software breakpoint),
 * since neither is an address or hardware-trigger exception. This core writes the
 * instruction bits into mtval for these exceptions. */
  .section .text
  .globl test_main
test_main:
  li t0, 0x1234
  csrw mtval, t0
  ecall
  li t0, 0x1234
  csrw mtval, t0
  ebreak
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  li t2, 11                 /* ECALL from M-mode */
  beq t0, t2, check_zero
  li t2, 3                  /* breakpoint (EBREAK) */
  beq t0, t2, check_zero
  FAIL(127)
check_zero:
  bnez t1, bad_tval
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
bad_tval:
  FAIL(1)
