#include "hyp.h"

/* VS-stage root table lives at GPA vs_root + 0x40000000 (G-stage gigapage 3),
 * which the G-stage maps execute-only onto the same host memory. The implicit
 * VS-stage PTE read is a load for G-stage purposes, so HLVX must raise a load
 * guest-page fault (cause 21) even though the final page is executable. */

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA gigapage 2 -> PA 0x80000000 RWX; gigapage 3 -> PA 0x80000000 X-only */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  /* VS-stage: VA gigapage 2 -> GPA 0x80000000 RWX */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  HGATP_ON
  la t2, vs_root
  li t3, 0x40000000
  add t2, t2, t3
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  csrw satp, zero
  li s0, 0            /* trap flag */
  ENTER_MODE(1, hs_code)

hs_code:
  la a1, target
expect_fault:
  hlvx.hu a2, (a1)
  /* reached only if no trap: bug */
  ecall

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li t5, 21
  bne t6, t5, 1f
  csrr t4, mepc
  la t5, expect_fault
  bne t4, t5, 2f
  PASS
1:
  li t5, 9            /* ecall from HS: HLVX did not fault */
  beq t6, t5, 3f
  FAIL(2)
2:
  FAIL(3)
3:
  FAIL(1)

target:
  nop

  HYP_TABLES
