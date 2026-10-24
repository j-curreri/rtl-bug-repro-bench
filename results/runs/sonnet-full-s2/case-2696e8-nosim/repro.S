#include "harness/hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x0..0x3fffffff -> PA 0x80000000, execute-only in G-stage */
  GIGA_LEAF(g_root, 0, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  csrw vsatp, zero
  li s1, 0
  ENTER_MODE(1, hs_code)

hs_code:
  li a1, 0x1000
  hlvx.wu a2, (a1)
  li s1, 1
  hlv.w a3, (a1)
  FAIL(3)

  .globl trap_handler
  .align 2
trap_handler:
  beqz s1, 1f
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 2f
  PASS
1: FAIL(1)
2: FAIL(2)

  HYP_TABLES
