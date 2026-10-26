#include "test.h"

# Uncompressed ecall/ebreak only, so mepc + 4 always steps past the instruction.
  .option norvc
  .section .text
  .globl test_main
test_main:
  ecall
  ebreak
  PASS

# Expected: mcause 11 (ecall from M-mode) or 3 (breakpoint), with mtval == 0.
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11
  beq t0, t1, 1f
  li t1, 3
  bne t0, t1, 2f
1:
  csrr t0, mtval
  bnez t0, 3f
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
2:
  FAIL(1)
3:
  FAIL(2)
