#include "test.h"

  .globl test_main
  .globl trap_handler

  .text
test_main:
  // Stage 0: Environment call (M-mode)
  csrw mscratch, zero
  li t0, 0x1234
  csrw mtval, t0
  ecall

  // Stage 1: Breakpoint
  li t0, 0x5678
  csrw mtval, t0
  .4byte 0x00100073 // ebreak

  // If both traps had mtval == 0, we pass
  PASS

  .align 2
trap_handler:
  csrr t1, mscratch
  bnez t1, check_ebreak

check_ecall:
  // Verify mcause is Environment call from M-mode (11)
  csrr t2, mcause
  li t3, 11
  bne t2, t3, fail_unexpected_trap

  // Privileged spec requires mtval == 0
  csrr t2, mtval
  bnez t2, fail_bad_mtval

  // Set stage 1 for ebreak
  li t1, 1
  csrw mscratch, t1

  // Advance mepc past ecall (4 bytes)
  csrr t2, mepc
  addi t2, t2, 4
  csrw mepc, t2
  mret

check_ebreak:
  // Verify mcause is Breakpoint (3)
  csrr t2, mcause
  li t3, 3
  bne t2, t3, fail_unexpected_trap

  // Privileged spec requires mtval == 0
  csrr t2, mtval
  bnez t2, fail_bad_mtval

  // Advance mepc past ebreak (4 bytes)
  csrr t2, mepc
  addi t2, t2, 4
  csrw mepc, t2
  mret

fail_unexpected_trap:
  FAIL(1)

fail_bad_mtval:
  FAIL(2)
