#include "test.h"
.option norvc
.globl test_main
.globl trap_handler
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s1, 0
  csrw tselect, x0
  li t0, 0x8000100f
  csrw tdata2, t0
  li t0, ((6 << 60) | (1 << 7) | (1 << 6) | 2)
  csrw tdata1, t0
  li t2, 0x80001004
  sw t3, 0(t2)
  nop
  li t0, 1
  bne s1, t0, bad
  PASS
bad:
  FAIL(1)
trap_handler:
  csrr t0, mcause
  li t1, 3
  bne t0, t1, bad
  addi s1, s1, 1
  csrw tdata1, x0
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
