#include "harness/hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* non-leaf at vs_root[0] with PPN bit 29 set (GPA bit 41) */
  RAW_PTE(vs_root, 0, ((1 << 29) << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)
vs_code:
  li t3, 0
  ld t4, 0(t3)
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
