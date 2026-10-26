/* MRET into M-mode with mstatus.MPV=1.
 * M-mode always runs with virtualization mode V=0, so MRET with MPP=M must
 * leave V=0 regardless of MPV. The buggy RTL copies MPV into V unconditionally,
 * so the ecall trap below records MPV=1 in mstatus (it saves the current V). */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* mstatus.MPV = 1, mstatus.MPP = M */
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0

  la t0, after_mret
  csrw mepc, t0
  mret

after_mret:
  ecall                     /* M-mode ecall: cause 11, saves V into mstatus.MPV */
  FAIL(2)                   /* not reached: trap_handler always ends the test */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t1, mcause
  li t2, 11
  bne t1, t2, 1f            /* must be M-mode ecall */

  csrr t0, mstatus
  srli t0, t0, 39
  andi t0, t0, 1
  bnez t0, 2f               /* MPV must be 0: trap was taken from V=0 */
  PASS

1:
  FAIL(3)
2:
  FAIL(1)
