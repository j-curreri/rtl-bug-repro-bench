#include "test.h"
  .text
  .globl test_main
  .globl trap_handler
test_main:
  li t0, 0x55
  csrw mtval, t0
  li t0, 8
  csrw mie, t0            # MSIE
  csrs mstatus, t0        # MIE
  li t1, 0x02000000
  li t0, 1
  sw t0, 0(t1)            # raise msip
  li t2, 20000
1:
  addi a1, a1, 0x7f
  addi t2, t2, -1
  bnez t2, 1b
  FAIL(1)                 # interrupt never taken

  .align 2
trap_handler:
  csrr t3, mcause
  bgez t3, bad
  csrr t4, mtval
  bnez t4, bad
  PASS
bad:
  FAIL(2)
