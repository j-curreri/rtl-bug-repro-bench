#define MPV (1<<39)
#include "test.h"
.globl test_main
.globl trap_handler
.text
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  li t0, (3 << 11)
  csrs mstatus, t0          # MPP = M
  li t0, MPV
  csrs mstatus, t0          # MPV = 1
  la t0, 1f
  csrw mepc, t0
  mret
1:
  ecall                      # trap from M-mode; MPV must record V
  FAIL(1)
.align 2
trap_handler:
  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, 2f
  PASS
2:
  FAIL(2)
