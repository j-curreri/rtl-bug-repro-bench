#include "harness/test.h"
#include "harness/hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  # vs_root[0]: non-leaf PTE, PPN = 1<<29 => GPA bit 41 set (outside Sv39x4)
  RAW_PTE(vs_root, 0, ((1 << 29) << 10) | PTE_V)
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_code)

  .align 2
vs_code:
  # code is at 0x80000000+, VA must be identity-mapped: map vs_root[2] as leaf
  li t2, 0
  ld t3, 0(t2)
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
