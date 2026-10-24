/* HLVX on an execute-only G-stage page fills the DTLB; a following plain HLV.D
 * to the same page must still raise a load guest-page fault (cause 21). */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li s0, 0
  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000, execute-only (no R/W). */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D))
  csrw vsatp, zero
  li t0, HSTATUS_SPVP
  csrs hstatus, t0
  HGATP_ON
  hfence.vvma

  la s1, target
  li s0, 1
  hlvx.hu t2, (s1)        /* allowed: X counts as R for HLVX */
  li t3, 0x1234
  bne t2, t3, fail_val
  li s0, 2
  hlv.d t4, (s1)          /* must fault: no R permission */
  li s0, 3
  FAIL(1)

fail_val:
  FAIL(4)

  .align 2
  .globl trap_handler
trap_handler:
  li t0, 2
  bne s0, t0, bad_stage
  csrr t1, mcause
  li t0, 21
  bne t1, t0, bad_cause
  PASS
bad_stage:
  FAIL(2)
bad_cause:
  FAIL(3)

  .data
  .align 3
target: .dword 0x1234
HYP_TABLES
