#include "test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li t0, -1
  csrw mtval, t0
  ecall
  csrr t1, mtval
  bnez t1, bad
  PASS
bad:
  FAIL(1)
.align 2
trap_handler:
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
