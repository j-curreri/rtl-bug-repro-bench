#include "hyp.h"

/* G-stage leaf at GPA 0x40000000 (1 GiB, index 1) -> PA 0x80000000, execute-only (R=0, X=1, U=1).
 * HLVX.HU may read through an execute-only G-stage page. A later plain HLV.D to the same page
 * must raise a load guest-page fault (cause 21) even though the DTLB now hits. */

  .section .text
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                 /* LOAD_GUEST_PAGE_FAULT */
  bne t0, t1, 1f
  csrr t0, mepc
  la t1, hlv_insn
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 1, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  HGATP_ON
  ENTER_MODE(1, hs_main)

hs_main:
  li s0, 0x40001000
  hlvx.hu t1, (s0)          /* execute-as-read: must succeed, fills the DTLB */
hlv_insn:
  hlv.d t2, (s0)            /* plain load: R=0 at G-stage, must fault */
  FAIL(2)

HYP_TABLES
