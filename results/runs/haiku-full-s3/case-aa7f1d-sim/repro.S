#include "hyp.h"

/* Bug: MRET to M-mode with mstatus.MPV set leaves V=1 while in M-mode (the spec says MPV is
 * ignored for M-mode returns and V must be 0 in M-mode). A later trap taken from M-mode then
 * latches mstatus.MPV = V = 1 on trap entry. A correct core latches MPV = 0. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  ENTER_MODE(3, m_target)

m_target:
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, 1f
  PASS
1:
  FAIL(1)
