#include "harness/hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* non-leaf PTE whose PPN has bits above the guest-physical range (bit 41) */
  RAW_PTE(vs_root, 0, ((1 << 29) << 10) | PTE_V)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_code)

  .align 2
vs_code:
  li t2, 0
  ld t3, 0(t2)
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
