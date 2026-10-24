/* VS-stage non-leaf PTE whose PPN points outside the 41-bit guest-physical
 * address space: a VS-mode load must raise a load guest-page fault (cause 21),
 * not a load page fault (cause 13). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity map GPA 0x80000000 (1 GiB) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: identity map VA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: VA 0xC0000000 -> non-leaf pointing to GPA 2^41 (out of range) */
  RAW_PTE(vs_root, 3, ((1 << 29) << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  ENTER_VS(vs_code)

vs_code:
  li t3, 0xC0000000
  ld t4, 0(t3)
  /* the load must not succeed */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 21
  beq t6, t5, 1f
  li t5, 13
  beq t6, t5, 2f
  FAIL(3)
2:
  FAIL(2)
1:
  /* trap must come from V=1 */
  csrr t5, mstatus
  li t4, MSTATUS_MPV
  and t5, t5, t4
  beqz t5, 3f
  PASS
3:
  FAIL(4)

HYP_TABLES
