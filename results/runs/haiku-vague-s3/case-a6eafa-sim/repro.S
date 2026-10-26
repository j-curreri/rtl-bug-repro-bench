#include "hyp.h"

/* Repro: a load from a VS-stage execute-only page (no R bit) must raise a load
 * page fault unless MXR is set. The first load runs with vsstatus.MXR = 1 and fills
 * the DTLB. After MXR is cleared, the second load hits in the DTLB; the hit path only
 * checks U-mode privilege for the VS-stage PTE, so the permission is never re-checked. */

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw hedeleg, zero

  /* G-stage: GPA 0x80000000 -> PA 0x80000000, fully permissive. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* VS-stage: identity map for code/data, and VA 0x40000000 -> PA 0x80000000
   * mapped execute-only (no R bit). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 1, 0x80000000, PTE_V | PTE_X | PTE_A | PTE_D)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  li t0, (1 << 19)      /* vsstatus.MXR */
  csrs vsstatus, t0

  ENTER_VS(vs_code)

vs_code:
  li t0, 0x40000000
  ld t1, 0(t0)          /* MXR=1: readable through X; fills the DTLB */
  li t0, (1 << 19)
  csrc sstatus, t0      /* clear MXR (sstatus is vsstatus in VS-mode) */
  li t0, 0x40000000
  ld t1, 0(t0)          /* must raise load page fault (cause 13) */
  ecall                 /* only reached if the load did not fault */

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li t5, 13
  bne t6, t5, 1f
  PASS
1:
  FAIL(3)

HYP_TABLES
