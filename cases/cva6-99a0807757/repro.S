/* A non-leaf VS-stage PTE whose PPN does not fit in a guest-physical address must raise a
 * guest-page fault (load: cause 21), not an ordinary page fault. */
#include "hyp.h"
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 3, (1 << 39) | PTE_V)   /* non-leaf, PPN bit 29 set */
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(in_vs)
in_vs:
  li t0, 0xC0000000
  ld t1, 0(t0)
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21
  beq t0, t1, 3f
  li t1, 13
  beq t0, t1, 2f
  FAIL(1)
2: FAIL(2)
3: PASS

  HYP_TABLES
