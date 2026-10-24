#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0 -> PA 0x80000000, execute-only (U set as required for G-stage) */
  GIGA_LEAF(g_root, 0, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  csrw vsatp, zero
  ENTER_MODE(1, hs_code)

hs_code:
  li a1, 0
  hlvx.wu a2, (a1)       /* must succeed */
  hlv.w a3, (a1)         /* must raise load guest-page fault */
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES
