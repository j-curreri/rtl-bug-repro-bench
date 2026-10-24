#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS root[0]: pointer whose PPN has bits above GPA range (bit 35 of ppn) */
  la t2, vs_root
  srli t2, t2, 12
  li t3, 1
  slli t3, t3, 35
  or t2, t2, t3
  slli t2, t2, 10
  ori t2, t2, PTE_V
  la t0, vs_root
  sd t2, 0(t0)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)
vs_code:
  li t4, 0x1000
  ld t5, 0(t4)
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1: FAIL(2)

  HYP_TABLES
