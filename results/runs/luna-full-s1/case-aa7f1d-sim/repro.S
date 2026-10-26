#include "test.h"

  .section .text
  .globl test_main
  .align 2
test_main:
  /* Request an MRET to M-mode with MPV set.  MPV must be ignored here. */
  li t0, (1 << 39)
  csrs mstatus, t0
  ENTER_MODE(3, after_mret)

after_mret:
  /* A trap from M-mode records the current virtualization state in MPV. */
  ecall
  FAIL(1)                    /* ECALL must trap to trap_handler. */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11                  /* Environment call from M-mode. */
  bne t0, t1, unexpected_trap

  csrr t0, mstatus
  li t1, (1 << 39)           /* MPV saved on trap entry. */
  and t0, t0, t1
  bnez t0, mpv_was_set
  PASS

mpv_was_set:
  FAIL(2)

unexpected_trap:
  FAIL(3)
