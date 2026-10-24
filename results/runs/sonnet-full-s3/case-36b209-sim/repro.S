#include "hyp.h"
.text
.globl test_main
.globl trap_handler
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* non-leaf PTE at vs_root[0] with PPN bit 30 set (GPA beyond 41 bits) */
  RAW_PTE(vs_root, 0, ((1 << 40) | PTE_V))
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)
vs_code:
  li t0, 0
  ld t1, 0(t0)
  FAIL(1)
trap_handler:
  csrr t0, mcause
  li t1, 21
  bne t0, t1, 1f
  PASS
1:
  FAIL(2)
HYP_TABLES
