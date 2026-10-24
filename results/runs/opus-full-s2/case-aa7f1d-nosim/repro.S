#include "test.h"
#include "hyp.h"

/* MRET with MPP=M and MPV=1 must stay in M-mode with V=0 (MPV ignored). */
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
  /* With V=0, sscratch must not be redirected to vsscratch. */
  csrr t0, sscratch
  li t1, 0x1111
  bne t0, t1, fail1

  /* A trap taken from M-mode with V=0 must record MPV=0. */
  ecall
  la t0, saved_mstatus
  ld t0, 0(t0)
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, fail2
  csrr t0, mcause
  li t1, 11
  bne t0, t1, fail3
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
fail3:
  FAIL(3)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  /* keep MPP=M so mret returns to M-mode; do not touch MPV */
  li t0, (3 << 11)
  csrs mstatus, t0
  csrr t0, mstatus
  la t1, saved_mstatus
  sd t0, 0(t1)
  mret

  .data
  .align 3
saved_mstatus: .dword 0
