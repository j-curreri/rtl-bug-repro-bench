#include "hyp.h"

#define MSTATUS_MIE  (1 << 3)
#define MSTATUS_MPIE (1 << 7)
#define MSTATUS_MPP  (3 << 11)
#define MSTATUS_MPRV (1 << 17)

  .text
  .globl test_main
test_main:
  /* Disable all interrupt sources so MRET cannot trigger spurious interrupts. */
  csrw mie, zero

  /* Write distinct values to HS-level sscratch and VS-level vsscratch. */
  li t0, 0x1111
  csrw sscratch, t0
  li t0, 0x2222
  csrw vsscratch, t0

  /* Baseline check: MRET with MPP = M-mode (3) and MPV = 0 keeps V = 0. */
  li t0, (MSTATUS_MIE | MSTATUS_MPIE | MSTATUS_MPRV | MSTATUS_MPV)
  csrc mstatus, t0
  li t0, MSTATUS_MPP
  csrs mstatus, t0
  la t0, 1f
  csrw mepc, t0
  mret

1:
  csrr t1, sscratch
  li t2, 0x1111
  bne t1, t2, fail_baseline
  hfence.vvma zero, zero

  /* Bug check: MRET with MPP = M-mode (3) and MPV = 1 must ignore MPV and keep V = 0. */
  li t0, (MSTATUS_MIE | MSTATUS_MPIE | MSTATUS_MPRV)
  csrc mstatus, t0
  li t0, (MSTATUS_MPP | MSTATUS_MPV)
  csrs mstatus, t0
  la t0, 2f
  csrw mepc, t0
  mret

2:
  /* On a compliant core V = 0, so sscratch reads 0x1111 and hfence.vvma is legal.
   * On the buggy core V = 1 in M-mode, so sscratch aliases vsscratch (0x2222)
   * and hfence.vvma raises a virtual-instruction exception. */
  csrr t1, sscratch
  li t2, 0x1111
  bne t1, t2, fail_bug
  hfence.vvma zero, zero

  PASS

fail_bug:
  FAIL(1)

fail_baseline:
  FAIL(2)
