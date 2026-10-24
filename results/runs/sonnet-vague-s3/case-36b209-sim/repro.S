#include "hyp.h"
  .text
  .globl test_main
test_main:
  la t0, trap_handler
  csrw mtvec, t0
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 0, (((1<<29) | 0x80000) << 10) | PTE_V)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_code)
vs_code:
  li t2, 0
  ld t3, 0(t2)
  FAIL(1)
  .align 2
trap_handler:
  csrr t0, mcause
  li t1, 21
  beq t0, t1, ok
  FAIL(2)
ok:
  PASS
  HYP_TABLES
