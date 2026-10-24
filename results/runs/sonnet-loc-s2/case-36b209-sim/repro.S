#include "test.h"
#include "hyp.h"
  .text
  .globl test_main
  .globl trap_handler
  .align 2
trap_handler:
  csrr t2, mcause
  li t3, 21
  bne t2, t3, 1f
  PASS
1:
  FAIL(1)

test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 0, 0x8000000001)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(vs_code)

  .align 4
vs_code:
  li t0, 0x1000
  ld t1, 0(t0)
  FAIL(2)

  HYP_TABLES
