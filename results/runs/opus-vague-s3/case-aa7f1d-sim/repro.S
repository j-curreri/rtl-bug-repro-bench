#include "hyp.h"
/* MRET with MPP=M and MPV=1 must return to M-mode with V=0 (MPV is ignored).
 * The buggy core sets V=MPV unconditionally. Detect V via sscratch/vsscratch
 * aliasing and via MPV recorded on a subsequent ecall trap. */
  .text
  .globl test_main
test_main:
  li t0, 0x1111
  csrw sscratch, t0
  li t0, 0x2222
  csrw vsscratch, t0
  /* MPP = M, MPV = 1 */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  /* MPV must now be cleared */
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, fail1
  /* With V=0, sscratch accesses sscratch, not vsscratch */
  csrr t0, sscratch
  li t1, 0x1111
  bne t0, t1, fail2
  /* Trap from M-mode: MPV must record V=0, MPP=M */
  la t0, after_ecall
  csrw mscratch, t0
  ecall
  FAIL(9)
after_ecall:
  li t1, MSTATUS_MPV
  and t0, s1, t1
  bnez t0, fail3
  PASS
fail1: FAIL(1)
fail2: FAIL(2)
fail3: FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 11            /* ecall from M */
  bne t6, t5, bad_trap
  csrr s1, mstatus
  csrr t0, mscratch
  csrw mepc, t0
  li t0, (3 << 11)
  csrs mstatus, t0     /* MPP = M */
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  mret
bad_trap:
  FAIL(4)
