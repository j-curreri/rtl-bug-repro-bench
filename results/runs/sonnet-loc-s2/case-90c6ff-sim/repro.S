#include "harness/hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: gpa 0xC0000000 (1G idx 3) -> pa 0x80000000, R/W/U/A/D, no X */
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V|PTE_R|PTE_W|PTE_U|PTE_A|PTE_D))
  HGATP_ON
  ENTER_MODE(1, s_code)

s_code:
  li s1, 0xC0000000
  hlv.w t2, 0(s1)        /* plain HLV: allowed, fills DTLB */
  hlv.w t2, 0(s1)
  hlvx.hu t2, 0(s1)      /* needs X in G-stage: must raise load guest page fault */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES
