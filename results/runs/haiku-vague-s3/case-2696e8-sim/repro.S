#include "hyp.h"

/* Bug: a DTLB hit for a hypervisor load ignores the G-stage read permission.
 * Step 1: HLVX.WU to a guest page that is execute-only (X=1, R=0). It is legal and
 *         fills the DTLB with that translation.
 * Step 2: plain HLV.W to the same page. It must raise a load guest page fault (21),
 *         because the page is not readable for an HLV access. The buggy core hits in
 *         the DTLB and never checks R, so the load succeeds. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity 1 GiB leaf for DRAM, execute-only (no R bit). */
  GIGA_LEAF(g_root, 2, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON

  /* HLV/HLVX run with effective privilege S (hstatus.SPVP=1). */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  la a1, buf
  hlvx.wu a2, (a1)          /* legal: execute permission satisfies HLVX */
hlv_insn:
  hlv.w a3, (a1)            /* must fault with LOAD_GUEST_PAGE_FAULT (21) */

  FAIL(1)                   /* reached only if the second load did not trap */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  csrr t4, mepc
  la t5, hlv_insn
  bne t4, t5, 1f            /* any trap other than at hlv_insn is unexpected */
  li t5, 21
  bne t6, t5, 1f
  PASS
1:
  FAIL(2)

  .data
  .align 3
buf: .dword 0x1122334455667788

HYP_TABLES
