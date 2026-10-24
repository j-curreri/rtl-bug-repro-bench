#include "hyp.h"

/* VS-stage non-leaf PTE whose PPN points at GPA 2^41 (outside Sv39x4's 41-bit
 * guest-physical space). A load through it must raise a load guest-page fault
 * (cause 21), not a load page fault (13). */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity map GPA 0x80000000 -> HPA 0x80000000 (1 GiB) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 leaf */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: VA 0xC0000000 -> non-leaf pointing to GPA 2^41 */
  RAW_PTE(vs_root, 3, ((1 << 29) << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)

vs_code:
  li a1, 0xC0000000
  ld a2, 0(a1)
  /* load must trap */
  ecall

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  /* fault must be from V=1 */
  csrr t4, mstatus
  li t5, MSTATUS_MPV
  and t4, t4, t5
  beqz t4, 2f
  PASS
1:
  li t5, 13
  beq t6, t5, 3f
  FAIL(2)
2:
  FAIL(3)
3:
  FAIL(1)

HYP_TABLES
