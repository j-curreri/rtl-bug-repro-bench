#include "hyp.h"

/* HLVX from M-mode (SPVP=1 -> VS-mode access). The VS-stage root table lives in
 * guest-physical memory that the G-stage maps execute-only. The implicit PTE read is
 * a load for G-stage checks, so the walk must raise a load guest-page fault (21). */
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 -> PA 0x80000000, execute-only (no R/W). */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000, RWX. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  fence
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  li t0, (1 << 19)          /* clear MXR */
  csrc mstatus, t0
  la a1, target
  hlvx.wu a0, (a1)
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  PASS
1:
  FAIL(2)

  .data
  .align 3
target: .word 0x12345678
HYP_TABLES
