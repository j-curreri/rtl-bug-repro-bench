#include "test.h"
#include "hyp.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* Request an MRET to M-mode with MPV set. MPV must be ignored. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  ENTER_MODE(3, after_mret)

after_mret:
  /* Trap entry records the current virtualization state in mstatus.MPV. */
  ecall
  FAIL(3) /* Reaching here means the ecall did not trap. */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11                 /* Environment call from M-mode. */
  bne t0, t1, unexpected_trap

  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, FAIL_mpv_set
  PASS

unexpected_trap:
  FAIL(1)
FAIL_mpv_set:
  FAIL(2)
