#include "hyp.h"

  .section .text
  .globl test_main
  .balign 4
test_main:
  PMP_ALLOW_ALL

  /* Keep traps in M-mode, disable interrupts, and use Bare address translation. */
  csrw medeleg, zero
  csrw mideleg, zero
  csrw mie, zero
  csrw hgatp, zero
  csrw vsatp, zero

  /* Ensure mstatus.GVA is 0 prior to entering VS-mode. */
  li t0, MSTATUS_GVA
  csrc mstatus, t0

  ENTER_VS(vs_entry)

  .balign 4
vs_entry:
vs_illegal_insn:
  /* Architectural defined illegal instruction (all zeros). */
  .4byte 0x00000000
  FAIL(10)

  .globl trap_handler
  .balign 4
trap_handler:
  /* 1. Verify trap cause is Illegal Instruction (mcause == 2). */
  csrr t0, mcause
  li t1, 2
  bne t0, t1, fail_cause

  /* 2. Verify faulting PC is vs_illegal_insn. */
  csrr t0, mepc
  la t1, vs_illegal_insn
  bne t0, t1, fail_epc

  /* 3. Verify trap originated from VS-mode (mstatus.MPV == 1, mstatus.MPP == S == 1). */
  csrr t0, mstatus
  li t1, MSTATUS_MPV
  and t2, t0, t1
  beqz t2, fail_mode
  srli t2, t0, 11
  andi t2, t2, 3
  li t1, 1
  bne t2, t1, fail_mode

  /* 4. Illegal-instruction traps do not write a GVA to mtval, so mstatus.GVA must be 0. */
  li t1, MSTATUS_GVA
  and t2, t0, t1
  bnez t2, fail_gva

  PASS

fail_cause:
  FAIL(1)
fail_epc:
  FAIL(2)
fail_mode:
  FAIL(3)
fail_gva:
  FAIL(4)
