/* HLVX must take a load guest-page fault when the VS-stage page table lives in
 * guest-physical memory that the G-stage maps execute-only (implicit PTE reads
 * are loads for G-stage permission purposes). */
#include "hyp.h"

#define GPA_ALIAS 0xC0000000   /* G-stage: GPA 0xC0000000 -> PA 0x80000000, X-only */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 -> PA 0x80000000 RWX (identity). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* G-stage: GPA 0xC0000000 -> PA 0x80000000 execute-only. */
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))

  /* VS-stage: VA 0x80000000 -> GPA 0x80000000 RWX (supervisor). */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  HGATP_ON

  /* vsatp root = GPA alias of vs_root (reachable only through the X-only mapping). */
  la t2, vs_root
  li t3, 0x80000000
  sub t2, t2, t3
  li t3, GPA_ALIAS
  add t2, t2, t3
  VSATP_ON(t2)

  /* HLVX as supervisor of the guest. */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  ENTER_MODE(1, hs_code)

hs_code:
  la a1, target
  li s0, 1               /* marks "inside the HLVX test" */
  hlvx.hu a2, (a1)
  li s0, 0
  FAIL(1)                /* buggy core: no fault */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 1
  bne s0, t5, bad_trap
  li t5, 21              /* load guest-page fault */
  bne t6, t5, wrong_cause
  PASS
wrong_cause:
  FAIL(2)
bad_trap:
  FAIL(3)

target:
  nop
  nop

  HYP_TABLES
