#include "hyp.h"

/* MRET with MPP=M and MPV=1 must return to M-mode with V=0 (MPV is ignored).
 * A subsequent ECALL from M-mode must therefore record MPV=0 in mstatus. */
  .text
  .globl test_main
test_main:
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  li t0, (3 << 11)
  csrs mstatus, t0          /* MPP = M */
  la t0, 1f
  csrw mepc, t0
  mret
1:
  li s0, 0                  /* trap counter */
  ecall
  li t0, 1
  bne s0, t0, fail_count
  li t0, 11                 /* ECALL from M-mode */
  bne s1, t0, fail_cause
  li t0, MSTATUS_MPV
  and t0, s2, t0
  bnez t0, fail_mpv
  PASS
fail_count:
  FAIL(1)
fail_cause:
  FAIL(2)
fail_mpv:
  FAIL(3)

  .align 2
  .globl trap_handler
trap_handler:
  addi s0, s0, 1
  csrr s1, mcause
  csrr s2, mstatus
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
