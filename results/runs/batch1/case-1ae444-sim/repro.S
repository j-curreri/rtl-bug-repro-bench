#include "test.h"
.globl test_main
.globl trap_handler
.text
test_main:
  li t0, 0x5a5a5a5a
  csrw mtval, t0
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 0x02004000      # mtimecmp
  sd zero, 0(t0)
  li t0, 0x80
  csrw mie, t0
  csrsi mstatus, 8
  li t1, 1000
1:
  addi t1, t1, -1
  bnez t1, 1b
  FAIL(1)
.align 4
trap_handler:
  csrr t0, mcause
  bgez t0, bad
  csrr t0, mtval
  bnez t0, bad
  PASS
bad:
  FAIL(2)
