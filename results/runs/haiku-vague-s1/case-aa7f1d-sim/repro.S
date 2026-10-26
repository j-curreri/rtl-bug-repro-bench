#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  # MPV=1 with MPP=M: mret should return to M-mode with virtualization off
  li t0, (1 << 39)
  csrs mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  ecall
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, 2f
  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, 3f
  PASS
2:
  FAIL(2)
3:
  FAIL(3)
