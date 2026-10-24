#include "test.h"
.text
.globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  # entry0: NA4 over `data`, RW; entry1: NAPOT all memory, X only
  la t0, data
  srli t0, t0, 2
  csrw pmpaddr0, t0
  li t0, -1
  csrw pmpaddr1, t0
  li t0, ((0x1c << 8) | 0x13)
  csrw pmpcfg0, t0
  ENTER_MODE(1, smode)
smode:
  la t1, data
  lw t2, 0(t1)
  li t3, 0x1234
  bne t2, t3, bad
  sw t3, 0(t1)
  li a7, 0
  ecall
bad:
  li a7, 1
  ecall
.align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 9
  bnez a7, 1f
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
.align 3
data: .word 0x1234, 0
