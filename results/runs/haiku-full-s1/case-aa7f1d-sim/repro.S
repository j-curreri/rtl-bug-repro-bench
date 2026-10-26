#include "test.h"
#include "hyp.h"

/* MRET to M-mode with mstatus.MPV set. The spec says MPV is ignored when returning
 * to M-mode, so the hart must stay non-virtualized. A later trap taken from M-mode
 * records the current virtualization mode in mstatus.MPV: it must read back as 0. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* Set MPV, then return to M-mode (MPP = 3) at `m_target`. */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0
  la t0, m_target
  csrw mepc, t0
  mret

m_target:
  /* Trap from M-mode. The handler inspects the MPV bit saved by the trap. */
  ecall

  /* Not reached: the handler does not return here. */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 11                 /* ENV_CALL_MMODE */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, 2f               /* MPV still set: bug reproduced */
  PASS
1:
  FAIL(3)                   /* unexpected trap cause */
2:
  FAIL(1)                   /* MPV leaked into M-mode */
