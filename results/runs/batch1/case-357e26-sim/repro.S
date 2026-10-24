#include "test.h"
.globl test_main
.globl trap_handler
.text
test_main:
  li t0, 0
  csrw pmpaddr0, t0
  li t0, 0x80004000
  srli t0, t0, 2
  ori t0, t0, 1
  csrw pmpaddr1, t0
  li t0, 0x0f00
  csrw pmpcfg0, t0
  ENTER_MODE(0, umode)
.align 2
umode:
  li t1, 0x80004000
  lb t2, 0(t1)
  ecall
.align 2
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, 1f
  PASS
1: mv a1, t0
  slli a0, a1, 1; ori a0, a0, 1; j _halt
