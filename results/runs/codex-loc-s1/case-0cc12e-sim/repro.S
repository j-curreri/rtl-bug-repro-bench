#include "test.h"
.section .text
.option norvc
.globl test_main
test_main:
  csrr s0, misa
  la t0, 1f
  addi t0, t0, 1
  jalr ra, 0(t0)
  FAIL(1)
1:
  la t0, test_main
  csrr s1, mstatus
  PASS
.globl trap_handler
.balign 4
trap_handler:
  csrr t6, mcause
  FAIL(127)
