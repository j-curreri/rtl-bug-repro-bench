#include "test.h"
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr t1, mcause
  bgez t1, seed
  li t2, 0x8000000000000003
  bne t1, t2, bad1
  csrr t1, mtval2
  bnez t1, bad4
  csrr t1, mstatus
  srli t2, t1, 11
  andi t2, t2, 3
  li t3, 3
  bne t2, t3, bad5
  andi t2, t1, 8
  bnez t2, bad6
  andi t2, t1, 0x80
  beqz t2, bad7
  PASS
seed:
  csrr t1, mepc
  addi t1, t1, 4
  csrw mepc, t1
  mret
bad1: FAIL(1)
bad2: FAIL(2)
bad3: csrr t1, mtinst; slli a0,t1,1; ori a0,a0,1; j _halt
bad4: FAIL(4)
bad5: FAIL(5)
bad6: FAIL(6)
bad7: FAIL(7)
test_main:
  li t0, 1
  nop
  li t0, 8
  csrw mie, t0
  csrs mstatus, t0
  li t0, 0x02000000
  li t1, 1
  sw t1, 0(t0)
1: j 1b
