#include "test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  li t0, 0x80100000
  srli t1, t0, 2
  ori t1, t1, 1
  csrw pmpaddr1, t1
  csrw pmpaddr0, x0
  li t0, 0x0f00
  csrw pmpcfg0, t0
  ENTER_MODE(0, user)
user:
  li t1, 0x80100000
  ld t2, 0(t1)
  ecall
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, 1f
  PASS
1: FAIL(1)
