#include "test.h"

  .section .text
  .globl test_main
  .align 2
test_main:
  /* M-mode environment calls and breakpoints must report mtval = 0. */
  li s0, 1
  ecall

  li s0, 2
  ebreak

  PASS

  /* The handler resumes only after validating both cause and mtval. */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mtval
  bnez t1, .Lbad_mtval

  li t2, 1
  beq s0, t2, .Lcheck_ecall
  li t2, 2
  beq s0, t2, .Lcheck_breakpoint
  j .Lunexpected

.Lcheck_ecall:
  li t2, 11                 /* Environment call from M-mode */
  bne t0, t2, .Lunexpected
  j .Lresume

.Lcheck_breakpoint:
  li t2, 3                  /* Breakpoint */
  bne t0, t2, .Lunexpected

.Lresume:
  csrr t0, mepc
  addi t0, t0, 4            /* ecall and ebreak are 32-bit instructions */
  csrw mepc, t0
  mret

.Lbad_mtval:
  FAIL(1)
.Lunexpected:
  FAIL(2)
