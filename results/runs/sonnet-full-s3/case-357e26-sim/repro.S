#include "harness/test.h"
.text
.globl test_main
.globl trap_handler
test_main:
  li t1, 0x80010000
  srli t0, t1, 2
  ori t0, t0, 1
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, (0x18 << 8) | 0x0f
  csrw pmpcfg0, t0
  ENTER_MODE(0, user)
user:
  li t1, 0x80010000
  lb t2, 0(t1)
  ecall
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, bad
  PASS
bad:
  FAIL(1)
