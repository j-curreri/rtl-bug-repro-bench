#include "harness/test.h"
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, (1 << 39)
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  # back in M-mode (V must be 0): sret to U-mode
  li t0, (1 << 8)
  csrc sstatus, t0
  la t0, 2f
  csrw sepc, t0
  sret
2:
  ecall
  FAIL(2)
trap_handler:
  csrr t0, mcause
  li t1, 8
  bne t0, t1, 3f
  PASS
3:
  FAIL(1)
