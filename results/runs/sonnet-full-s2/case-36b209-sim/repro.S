#include "harness/hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* non-leaf PTE at vs_root[0] with PPN bit 30 set (GPA beyond 41 bits) */
  RAW_PTE(vs_root, 0, ((1 << 40) | 1))
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)
  .align 2
vs_code:
  li t3, 0
  ld t4, 0(t3)
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t5, mcause
  li t6, 21
  bne t5, t6, 1f
  PASS
1:
  FAIL(2)

HYP_TABLES
