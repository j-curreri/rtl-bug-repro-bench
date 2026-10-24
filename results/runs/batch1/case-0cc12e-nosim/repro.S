#include "test.h"
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr t1, mcause
  csrr t2, mtval
  csrr t3, mepc
  li t4, 11
  bne t1, t4, 1f
  bnez t2, bad          # ecall: mtval must be 0
  addi t3, t3, 4
  csrw mepc, t3
  mret
1:
  li t4, 3
  bne t1, t4, bad
  beqz t2, 2f           # ebreak: mtval is 0 or the faulting pc
  bne t2, t3, bad
2:
  addi t3, t3, 4
  csrw mepc, t3
  mret
bad:
  FAIL(1)

test_main:
  ecall
  .option push
  .option norvc
  ebreak
  .option pop
  PASS
