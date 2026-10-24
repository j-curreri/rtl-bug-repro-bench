/* Two-stage translation: a VS-stage non-leaf PTE whose PPN points to a
 * guest-physical address beyond the Sv39x4 range (GPA bits >= 41 set).
 * The implicit G-stage translation of the next-level table address must
 * fail with a guest-page fault (load: cause 21), not a page fault (13). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity map GPA 0x80000000 (1 GiB) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  /* VS-stage: VA 0x0 -> non-leaf pointer to GPA 1<<41 (out of range) */
  RAW_PTE(vs_root, 0, ((1 << 29) << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  li s0, 0            /* phase marker */
  ENTER_VS(vs_code)

vs_code:
  /* sanity: mapped load works */
  la t0, data_word
  ld t1, 0(t0)
  li t2, 0x1234
  bne t1, t2, bad_sanity
  li s0, 1
  li t0, 0x1000
  ld t1, 0(t0)        /* must trap with load guest-page fault */
  li s0, 2
  ecall
bad_sanity:
  li s0, 3
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 1
  bne s0, t5, 1f
  li t5, 21
  bne t6, t5, 2f
  PASS
1:
  FAIL(1)
2:
  li t5, 13
  beq t6, t5, 3f
  FAIL(2)
3:
  FAIL(3)

  .data
  .align 3
data_word: .dword 0x1234
  HYP_TABLES
