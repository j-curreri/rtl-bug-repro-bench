/* Bug: with the H extension, MRET to M-mode with mstatus.MPV = 1 leaves the hart in
 * virtualization mode (V = 1). M-mode always runs with V = 0, so the trap taken from
 * M-mode afterwards must record MPV = 0. The buggy core records MPV = 1 (FAIL(2)). */
#include "hyp.h"

  /* Set expected mcause, resume address, then mret into (mpp, mpv) at target. */
  .macro ENTER_CASE mpp, mpv, target, cause, next
  la t0, exp_cause
  li t1, \cause
  sd t1, 0(t0)
  la t0, resume_addr
  la t1, \next
  sd t1, 0(t0)
  li t0, (3 << 11)
  csrc mstatus, t0
  li t0, (\mpp << 11)
  csrs mstatus, t0
  li t0, (1 << 39)
  csrc mstatus, t0
  li t0, (\mpv << 39)
  csrs mstatus, t0
  la t0, \target
  csrw mepc, t0
  mret
  .endm

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* MRET to M-mode (MPP = 3) with MPV = 1, then take an ecall from M-mode. */
  ENTER_CASE 3, 1, m_t, 11, done
m_t:
  ecall
done:
  PASS

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  la t5, exp_cause
  ld t4, 0(t5)
  bne t6, t4, 1f
  /* The trap saved the virtualization mode in mstatus.MPV; it must be 0. */
  csrr t3, mstatus
  srli t3, t3, 39
  andi t3, t3, 1
  bnez t3, 2f
  /* Return to the resume address in M-mode with MPV cleared. */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, (1 << 39)
  csrc mstatus, t0
  la t5, resume_addr
  ld t4, 0(t5)
  csrw mepc, t4
  mret
1:
  FAIL(1)
2:
  FAIL(2)

  .data
  .align 3
exp_cause:   .dword 0
resume_addr: .dword 0
