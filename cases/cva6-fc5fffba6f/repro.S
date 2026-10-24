/* MRET with MPP=M must leave V=0 even if MPV=1. A later trap records V in mstatus.MPV. */
#include "hyp.h"
  .text
  .globl test_main
test_main:
  li t0, (3 << 11)
  csrs mstatus, t0
  li t0, MSTATUS_MPV
  csrs mstatus, t0
  la t0, after
  csrw mepc, t0
  mret
after:
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 11                    /* ecall from M-mode */
  bne t0, t1, 1f
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t0, t0, t1
  bnez t0, 2f
  PASS
1: FAIL(1)
2: FAIL(2)
