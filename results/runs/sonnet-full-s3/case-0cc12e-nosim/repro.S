#include "harness/test.h"
.globl test_main
.globl trap_handler
test_main:
  li t0, 0x1234
  csrw mtval, t0
  ecall
  PASS
trap_handler:
  csrr t0, mtval
  beqz t0, 1f
  FAIL(1)
1:
  csrr t1, mepc
  addi t1, t1, 4
  csrw mepc, t1
  mret
