#include "test.h"
#include "hyp.h"

/* Two-stage translation: a store to a page that is read-only at the VS-stage and at the
 * G-stage must raise a store page fault (VS-stage checks come first). The DTLB is primed by
 * a load, so the store hits the cached entry, where the core checks the G-stage PTE first and
 * reports a store guest-page fault instead. */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: root[2] -> g_l1; g_l1[0] = 2 MiB RWX at 0x80000000; g_l1[2] = 2 MiB read-only at 0x80400000 */
  la t0, g_l1
  srli t0, t0, 2
  ori t0, t0, PTE_V
  la t1, g_root
  sd t0, 16(t1)

  la t1, g_l1
  li t0, ((0x80000000 >> 12) << 10) | G_RWX
  sd t0, 0(t1)
  li t0, ((0x80400000 >> 12) << 10) | (PTE_V | PTE_R | PTE_U | PTE_A | PTE_D)
  sd t0, 16(t1)

  /* VS-stage: root[2] = 1 GiB RWX identity for code; root[3] = 1 GiB read-only (gva 0xC0000000 -> gpa 0x80000000) */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 3, 0x80000000, PTE_V | PTE_R | PTE_A | PTE_D)

  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)

  ENTER_VS(vs_main)

  .align 2
vs_main:
  li a0, 0xC0400000
  ld t0, 0(a0)          /* load fills the TLB, must succeed */
  sd t0, 0(a0)          /* store hits the cached entry: expect STORE_PAGE_FAULT (15) */
  FAIL(3)               /* no trap at all */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 15
  bne t6, t5, 1f
  PASS
1:
  FAIL(2)

  HYP_TABLES
  .align 12
g_l1: .space 4096
