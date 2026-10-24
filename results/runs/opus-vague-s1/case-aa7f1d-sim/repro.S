#include "hyp.h"

.text
.globl test_main
test_main:
  PMP_ALLOW_ALL
  /* MPP = M, MPV = 1: MRET must keep V = 0 (MPV ignored when MPP = M). */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret
1:
  /* Now in M-mode; trap with ecall and check MPV saved by the trap is 0. */
  ecall
  FAIL(2)

.align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11
  bne t0, t1, bad_cause
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, bad_mpv
  li t1, (3 << 11)
  csrr t0, mstatus
  and t0, t0, t1
  bne t0, t1, bad_mpp
  PASS
bad_cause:
  FAIL(3)
bad_mpv:
  FAIL(4)
bad_mpp:
  FAIL(5)
