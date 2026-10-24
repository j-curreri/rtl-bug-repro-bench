/* Two-stage translation: a VS-stage non-leaf PTE whose next-level table lies at a
 * guest-physical address >= 2^41 (outside Sv39x4) must raise a load guest-page
 * fault (cause 21), since the G-stage translation of that implicit access fails.
 * The buggy core reports a plain load page fault (cause 13) instead. */
#include "hyp.h"
  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity map GPA 0x80000000 (1 GiB) */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* VS-stage: identity map VA 0x80000000; VA 0xC0000000 -> non-leaf at GPA 2^41 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 3, ((1 << 41) >> 12 << 10) | PTE_V)
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  li s1, 0
  ENTER_VS(vs_code)

vs_code:
  /* sanity: a mapped load must work without trapping */
  la t3, scratch
  ld t4, 0(t3)
  li a0, 0
  li s1, 1                  /* arm: next trap is the expected one */
  li t3, 0xC0000000
  ld t4, 0(t3)
  li s1, 0
  li t0, 21
  beq a0, t0, 1f
  bnez a0, 2f
  FAIL(3)                   /* no fault at all */
2: FAIL(2)                  /* wrong cause (13 on the buggy core) */
1: PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr a0, mcause
  beqz s1, unexpected
  li s1, 0
  csrr t0, mepc
  addi t0, t0, 4
  csrw mepc, t0
  mret
unexpected:
  FAIL(1)

  .data
  .align 3
scratch: .dword 0
HYP_TABLES
