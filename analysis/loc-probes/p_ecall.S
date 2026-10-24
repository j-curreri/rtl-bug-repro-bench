#include "hyp.h"
.globl test_main
.globl trap_handler
.align 2
trap_handler:
  csrr t0, mcause
  csrr t1, mstatus
  srli t1, t1, 39
  andi t1, t1, 1
  slli t0, t0, 4
  slli t1, t1, 2
  or a0, t0, t1
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt
test_main:
  PMP_ALLOW_ALL
  la t0, trap_handler
  csrw mtvec, t0
  ENTER_VS(vs)
.align 2
vs:
  ecall
  ecall
