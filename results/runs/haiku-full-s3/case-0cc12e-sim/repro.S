#include "test.h"

# Bug: mtval is not zeroed for ECALL and EBREAK traps (the RTL only zeroes it when
# ZERO_TVAL is set, which it is not in this build). The privileged spec requires
# mtval = 0 for these causes. Each trap checks the cause and mtval, then skips the
# 4-byte instruction and returns.

  .section .text
  .globl test_main
test_main:
  li s1, 11              # expected cause: environment call from M-mode
  ecall
  li s1, 3               # expected cause: breakpoint
  ebreak
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  bne t0, s1, 1f
  csrr t1, mtval
  bnez t1, 2f
  csrr t2, mepc
  addi t2, t2, 4
  csrw mepc, t2
  mret
1: FAIL(1)             # unexpected cause
2: FAIL(2)             # mtval not zero for ecall/ebreak
