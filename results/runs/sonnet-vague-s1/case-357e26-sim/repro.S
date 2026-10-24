#include "harness/test.h"
.text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li t0, 0x80003000
  srli t1, t0, 2
  csrw pmpaddr0, t1
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f10
  csrw pmpcfg0, t0
  ENTER_MODE(1, smode)
smode:
  li t0, 0x80003000
  lw t1, 0(t0)
  ecall
.globl trap_handler
.align 2
trap_handler:
  csrr t0, mcause
  csrr t0, mcause
  li t1, 5
  bne t0, t1, 1f
  PASS
1:
  slli a0, t0, 1
  ori a0, a0, 1
  j _halt
