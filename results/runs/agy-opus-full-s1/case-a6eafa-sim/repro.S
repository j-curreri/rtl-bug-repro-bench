/* HLVX with a VS-stage page table that lives in guest-physical memory the
 * G-stage maps execute-only. The implicit VS-stage PTE read is a load for the
 * G-stage check, so a correct core raises a load guest-page fault (cause 21). */
#include "hyp.h"

#define G_XONLY (PTE_V | PTE_X | PTE_U | PTE_A)

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000, execute-only. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_XONLY)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000, RWX (supervisor). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)

  /* HLV* from HS-mode act as VS-mode supervisor accesses. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Enter HS-mode (V=0). */
  li t0, MSTATUS_MPV
  csrc mstatus, t0
  ENTER_MODE(1, hs_code)

hs_code:
  la a1, test_main       /* 4-byte aligned code address */
  li s0, 0
  hlvx.wu a2, (a1)
  /* Reached only if HLVX did not fault: bug. */
  li s0, 1
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  bnez s0, 1f            /* ecall after successful HLVX */
  li t5, 21              /* load guest-page fault */
  bne t6, t5, 2f
  PASS
1:
  FAIL(1)
2:
  /* unexpected trap: report 16 + mcause */
  addi a0, t6, 16
  slli a0, a0, 1
  ori a0, a0, 1
  j _halt

  HYP_TABLES
