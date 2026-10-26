/* Reproducer: VS-mode load whose VS-stage walk reaches a non-leaf PTE whose
 * next-level pointer lies outside the guest-physical address space.
 * The spec requires LOAD_GUEST_PAGE_FAULT (21); the buggy core reports
 * LOAD_PAGE_FAULT (13), which the handler turns into FAIL. */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: identity-map the DRAM GiB (GPA 0x80000000 -> HPA 0x80000000). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  HGATP_ON

  /* VS-stage root: VA 0x80000000 -> identity (code/data fetch),
   * VA 0 -> non-leaf PTE (V=1, R=W=X=0) with PPN[43:29] != 0. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  RAW_PTE(vs_root, 0, (1 << 39) | PTE_V)
  la t2, vs_root
  VSATP_ON(t2)

  ENTER_VS(vs_test)

  .align 2
vs_test:
  li t0, 0
  ld t1, 0(t0)      /* must raise a guest-page fault */
  ecall             /* not reached on a correct core */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21         /* LOAD_GUEST_PAGE_FAULT */
  bne t0, t1, 1f
  PASS
1:
  FAIL(1)

HYP_TABLES
