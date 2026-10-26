#include "hyp.h"

/* Bug: MRET to M-mode (MPP=M) with mstatus.MPV=1 leaves V=1 while the hart is in M-mode.
 * The spec says MPV is ignored when returning to M-mode, so V must be 0 there.
 *
 * Observation: a trap taken to M-mode saves the current virtualization mode into
 * mstatus.MPV. On a correct core V=0 in M-mode, so MPV reads 0 in the trap handler.
 * On the buggy core the saved V is 1, so the handler sees MPV=1 and fails. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Request MPV=1 and MPP=M, then MRET into M-mode. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  ENTER_MODE(3, m_mode_entry)

m_mode_entry:
  /* Trap to M-mode from M-mode. The handler checks the saved MPV. */
  ecall

  /* Not reached: the handler always ends the test. */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11               /* must be the expected ecall-from-M trap */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, 2f             /* MPV set in M-mode: bug */
  PASS
1:
  FAIL(3)
2:
  FAIL(4)
