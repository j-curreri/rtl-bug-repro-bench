#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* non-leaf PTE (V only) whose PPN has bit 29 set: GPA beyond 41 bits */
  RAW_PTE(vs_root, 0, ((1 << 39) | PTE_V))
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)

  .align 2
vs_code:
  li t3, 0x1000
  ld t4, 0(t3)
  FAIL(1)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES
