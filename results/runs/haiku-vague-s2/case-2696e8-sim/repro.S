#include "hyp.h"

/* HLV.W from HS-mode to a guest-physical page that is execute-only in the G-stage,
 * with mstatus.MXR set. Plain HLV needs G-stage read permission, and MXR must not
 * grant it (only HLVX may read execute-only G-stage pages), so the correct core
 * raises a load guest-page fault (cause 21). The buggy core lets the load succeed. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: 1 GiB execute-only leaf for GPA 0x80000000 (root index 2). */
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON

  /* VS-stage bare, so guest VA == GPA. */
  csrw vsatp, zero

  /* Make mstatus.MXR (seen by S/VS-stage and HLV) = 1. */
  li t0, (1 << 19)
  csrs mstatus, t0

  /* HLV acts with supervisor privilege. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  ENTER_MODE(1, hs_code)

  .globl hs_code
hs_code:
  la a0, scratch
  hlv.w a1, (a0)
  /* Reached only if the plain HLV read of an execute-only G-stage page succeeded. */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  .data
  .align 3
scratch: .dword 0x1122334455667788

HYP_TABLES
