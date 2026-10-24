#include "hyp.h"

/* VS-mode load through a VS-stage non-leaf PTE whose PPN points at GPA 2^41,
 * outside the Sv39x4 guest-physical space. Spec: load guest-page fault (21). */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 (code/data) */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: VA 0xC0000000 -> non-leaf pointer to GPA 2^41 */
  RAW_PTE(vs_root, 3, ((1 << 29) << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  csrw medeleg, zero
  csrw hedeleg, zero
  ENTER_VS(vs_code)

vs_code:
  li t3, 0xC0000000
  ld t4, 0(t3)
  /* no fault at all */
  li a0, 0
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  beq t6, t5, 1f
  li t5, 13
  beq t6, t5, 2f
  FAIL(3)
1:
  PASS
2:
  FAIL(2)

HYP_TABLES
