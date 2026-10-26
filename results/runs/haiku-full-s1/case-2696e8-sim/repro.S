/* Reproducer: an HLVX read of a G-stage execute-only page is followed by a plain
 * HLV load of the same page. Correct RTL raises a load guest-page fault (cause 21)
 * on the HLV; the buggy DTLB-hit path lets it succeed. */
#include "hyp.h"

#define LOAD_GUEST_PAGE_FAULT 21
#define GPA_XONLY 0xC0000000   /* G-stage 1 GiB leaf: X|U only, maps to DRAM 0x80000000 */

HYP_TABLES

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity-map DRAM as RWXU, and map GPA 0xC0000000 execute-only (no R). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON

  /* HLV/HLVX use hstatus.SPVP as the effective privilege (S). */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Enter HS-mode (V=0) with translation off in VS, so accesses go through G-stage only. */
  ENTER_MODE(1, hs_entry)

hs_entry:
  li s0, GPA_XONLY

  /* HLVX.HU from the execute-only page must succeed and fill the translation cache. */
  hlvx.hu t1, 0(s0)

  /* A plain HLV.D from the same page must raise a load guest-page fault. */
hlv_insn:
  hlv.d t2, 0(s0)

  /* Reached only if the HLV did not trap: the bug. */
  FAIL(2)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, LOAD_GUEST_PAGE_FAULT
  bne t0, t1, 1f
  csrr t0, mepc
  la t1, hlv_insn
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)
