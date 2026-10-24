#include "test.h"
.globl test_main
.globl trap_handler
test_main:
  li t0, 0x5a5a5a5a
  csrw mtval, t0
  la t0, trap_handler
  csrw mtvec, t0
  li t1, 0x02004000
  sd zero, 0(t1)
  li t0, 0x88
  csrs mie, t0
  li t0, 8
  csrs mstatus, t0
  nop
  nop
  nop
  FAIL(9)
.align 4
trap_handler:
  csrr t0, mcause
  bgez t0, bad
  csrr t2, mtval
  bnez t2, bad
  PASS
bad:
  FAIL(1)
