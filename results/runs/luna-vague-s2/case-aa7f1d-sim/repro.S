#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Arrange an MRET with MPV=1 and MPP=M.  MRET must discard MPV when
     returning to M-mode, since virtualization mode is always zero in M. */
  li t0, (3 << 11)
  csrc mstatus, t0
  csrs mstatus, t0
  li t0, (1 << 39)
  csrs mstatus, t0
  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  /* The trap records the current virtualization state in mstatus.MPV. */
  ecall
  FAIL(1)                         /* Ecall should always trap in M-mode. */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11                       /* Environment call from M-mode. */
  bne t0, t1, unexpected_trap
  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, bad_mpv
  PASS

unexpected_trap:
  FAIL(2)
bad_mpv:
  FAIL(3)
