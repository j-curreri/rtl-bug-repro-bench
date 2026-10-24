/* mret with mstatus.MPP=M must leave V=0 even if mstatus.MPV=1
 * (H extension: "V is set to MPV, unless MPP=3, in which case V remains 0").
 * The buggy core sets V=MPV unconditionally, so M-mode code then runs with V=1:
 * sscratch accesses are redirected to vsscratch and a later trap records MPV=1. */
#include "test.h"
#include "hyp.h"

  .text
  .globl test_main
test_main:
  li t0, 0x11
  csrw sscratch, t0
  li t0, 0x22
  csrw vsscratch, t0

  /* MPP=M, MPV=1, then mret to the next label (stays in M-mode) */
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, in_m
  csrw mepc, t0
  mret

in_m:
  /* with V=0, sscratch is the HS register */
  csrr t0, sscratch
  li t1, 0x11
  bne t0, t1, fail_v
  /* an M-mode ecall must record MPV=0 (V was 0 at the trap) */
  ecall
  FAIL(3)

fail_v:
  FAIL(1)

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
  PASS
bad_cause:
  FAIL(4)
bad_mpv:
  FAIL(2)
