/* VS-stage non-leaf PTE whose PPN points outside the 41-bit guest-physical
 * address space (Sv39x4) must raise a load guest-page fault (cause 21). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 -> PA 0x80000000 (1 GiB) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 (code/data) */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: VA 0 -> non-leaf pointer with PPN bit 29 set (GPA bit 41) */
  RAW_PTE(vs_root, 0, ((1 << 29) << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)

vs_code:
  li t3, 0x1000
  ld t4, 0(t3)
  /* the load must not complete */
  li a0, 0
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  PASS
1:
  li t5, 13
  bne t6, t5, 2f
  FAIL(2)  /* buggy: plain load page fault */
2:
  FAIL(1)

HYP_TABLES
