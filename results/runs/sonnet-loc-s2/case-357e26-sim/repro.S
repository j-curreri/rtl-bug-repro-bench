#include "harness/test.h"
.section .text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  la t1, target
  srli t1, t1, 2
  csrw pmpaddr0, t1        # NA4, no permissions
  li t0, -1
  csrw pmpaddr1, t0
  li t0, 0x1f10
  csrw pmpcfg0, t0
  ENTER_MODE(0, umode)
.align 2
umode:
  la t1, target
  lw t2, 0(t1)
  FAIL(1)
.align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 5
  bne t0, t1, bad
  PASS
bad:
  FAIL(2)
.section .data
.align 3
target: .dword 0x1234
