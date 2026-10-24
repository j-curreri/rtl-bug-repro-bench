#include "harness/test.h"
.globl test_main
.globl trap_handler
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 0x80
  csrs mie, t0          # MSIE
  li t0, 0x02000000
  li t1, 1
  li t0, 0x02004000; sd zero, 0(t0)
  csrsi mstatus, 8      # enable MIE
  li t2, 0x12345
1:
  addi t2, t2, 1
  addi t2, t2, 1
  addi t2, t2, 1
  j 1b
trap_handler:
  csrr t0, mcause
  bgez t0, bad
  li t1, 0x02000000
  li t1, 0x02004000; li t2, -1; sd t2, 0(t1)
  csrr t0, mtval
  bnez t0, bad
  PASS
bad:
  FAIL(1)
