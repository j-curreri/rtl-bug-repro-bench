#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* Arrange for MRET to return to M-mode with MPV set. */
  li t0, ((3 << 11) | (1 << 39))
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  /* Trap entry copies the current virtualization state into mstatus.MPV. */
  ecall
  FAIL(1)                    /* The ecall must trap. */

  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11                  /* Environment call from M-mode. */
  bne t0, t1, unexpected_trap
  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, FAIL_virtualized
  PASS

unexpected_trap:
  FAIL(2)
FAIL_virtualized:
  FAIL(3)
