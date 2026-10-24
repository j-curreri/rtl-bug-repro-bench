#include "test.h"
.option norvc
.globl test_main
.globl trap_handler
test_main:
  li t0, -1
  csrw mtval, t0
  la t0, h
  csrw mtvec, t0
  li s1, 0
a1:
  ecall
  csrr t1, mtval
  bnez t1, bad1
  # ebreak: mtval must be 0 or the pc
  li t0, -1
  csrw mtval, t0
a2:
  ebreak
  csrr t1, mtval
  beqz t1, ok2
  la t2, a2
  bne t1, t2, bad2
ok2:
  PASS
bad1: FAIL(1)
bad2: FAIL(2)
h:
trap_handler:
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
