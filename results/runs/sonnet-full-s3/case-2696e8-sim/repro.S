#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* GPA 0x00000000-0x3fffffff -> identity not needed; map GPA 3GiB -> PA 0x80000000, execute-only */
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  HGATP_ON
  csrw vsatp, zero
  la t0, trap_handler2
  csrw mtvec, t0
  li t2, 0xC0000000
  li t5, 0
  hlvx.wu t3, (t2)
  li t5, 1
  hlv.w t4, (t2)        /* must raise load guest-page fault */
  FAIL(1)

  .align 2
trap_handler2:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  beqz t5, 1f
  PASS
1: FAIL(2)

HYP_TABLES
