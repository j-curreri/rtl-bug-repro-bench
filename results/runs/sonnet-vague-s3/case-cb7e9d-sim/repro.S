#include "harness/test.h"
.option norvc
.globl test_main
.globl trap_handler
.text
trap_handler:
  csrr t5, mcause
  li t6, 3
  bne t5, t6, 1f
  addi s1, s1, 1
  csrr t5, mepc
  addi t5, t5, 4
  csrw mepc, t5
  mret
1: FAIL(60)

test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li s2, 0x80030000
  li s1, 0
  # mcontrol6, match=1 (napot), M-mode, load address
  li t0, (6<<60) | (1<<7) | (1<<6) | 1
  csrw tdata1, t0
  li t0, 0x8003ffff        # napot: matches 0x80030000-0x8003ffff
  csrw tdata2, t0
  lw t1, 0(s2)
  csrw tdata1, x0
  bnez s1, 1f
  FAIL(1)
1:
  PASS
