#include "test.h"
.option norvc
.globl test_main
.globl trap_handler
.text
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s1, 0
  csrw tselect, x0
  la t1, target
  ori t2, t1, 7          # NAPOT region of 16 bytes (bit 3 is 0, target 16-aligned)
  csrw tdata2, t2
  li t3, (1<<6)|(1<<7)|(1<<2)   # m, match=1 (napot), execute
  li t0, 6
  slli t0, t0, 60
  or t0, t0, t3
  csrw tdata1, t0
  addi t1, t1, 4
  jr t1                  # executes inside the region (target+4)
cont:
  csrw tdata1, x0
  li t0, 1
  bne s1, t0, fail
  PASS
fail:
  FAIL(1)
trap_handler:
  csrr t5, mcause
  li t6, 3
  bne t5, t6, bad
  addi s1, s1, 1
  la t5, cont
  csrw mepc, t5
  mret
bad:
  FAIL(2)
.align 4
target:
  nop
  j cont
  nop
  nop
