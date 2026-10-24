#include "test.h"
.text
.globl test_main
.globl trap_handler
.align 4
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  csrw tselect, x0
  la t1, target
  ori t1, t1, 7
  csrw tdata2, t1
  li t0, 6
  slli t0, t0, 60
  li t2, (1<<6)|(1<<2)|(1<<7)   # m, execute, match=napot
  or t0, t0, t2
  csrw tdata1, t0
  la t0, target
  jr t0
.align 5
target:
  nop
  nop
  nop
  nop
  FAIL(1)
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
