#include "harness/test.h"
.globl test_main
.globl trap_handler
test_main:
  ecall
  FAIL(1)
.align 2
trap_handler:
  csrr t0, mtval
  bnez t0, bad
  PASS
bad:
  FAIL(2)
