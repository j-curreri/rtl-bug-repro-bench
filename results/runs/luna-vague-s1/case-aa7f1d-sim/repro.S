#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  # MPP=M and MPV=1 is a legal saved state, but MRET to M must clear V.
  li t0, (3 << 11) | (1 << 39)
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  # Force a trap from the state reached by MRET. The trap handler checks
  # that the trap did not save a virtualized context in mstatus.MPV.
  ecall
  FAIL(1)                     # ecall must trap

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11                   # Environment call from M-mode
  bne t0, t1, unexpected_trap
  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, unexpected_trap    # Correct MRET returned with V=0
  PASS

unexpected_trap:
  FAIL(2)
