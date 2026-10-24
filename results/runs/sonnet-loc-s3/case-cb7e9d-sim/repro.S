#include "harness/test.h"
.option norvc
.text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s1, 0
  li t0, 0x80003000
  li t1, 0x800037ff       # NAPOT range 0x80003000..0x800037ff
  csrw tselect, x0
  csrw tdata2, t1
  li t1, 6
  slli t1, t1, 60
  li t2, (1<<7) | (1<<6) | 1   # match=napot, m, load
  or t1, t1, t2
  csrw tdata1, t1
  lw t3, 0x120(t0)        # must trigger breakpoint
  bnez s1, ok
  FAIL(1)
ok:
  PASS
.align 2
.globl trap_handler
trap_handler:
  csrr t4, mcause
  li t5, 3
  bne t4, t5, bad
  li s1, 1
  csrw tdata1, x0
  csrr t4, mepc
  addi t4, t4, 4
  csrw mepc, t4
  mret
bad:
  slli a0, t4, 4; ori a0, a0, 1; j _halt
