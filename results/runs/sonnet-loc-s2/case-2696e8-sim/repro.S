#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* guest 0x0 -> pa 0x80000000, execute-only G-stage leaf */
  GIGA_LEAF(g_root, 0, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  ENTER_MODE(1, hs_code)

hs_code:
  li a1, 0
  hlvx.hu a2, (a1)      /* allowed: execute permission, fills DTLB */
  hlv.hu a3, (a1)       /* must raise load guest page fault */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t5, mcause
  li t4, 21
  bne t5, t4, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES
