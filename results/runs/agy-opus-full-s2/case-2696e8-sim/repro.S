/* Reproducer: after an HLVX load from a G-stage execute-only page fills the DTLB,
 * a plain HLV load from the same page must still raise a load guest-page fault
 * (mcause 21). Only HLVX may treat execute permission as read permission. */
#include "hyp.h"

#define CAUSE_LOAD_GUEST_PAGE_FAULT 21

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: GPA 0x80000000 (1 GiB) -> PA 0x80000000, execute-only (no R/W). */
  GIGA_LEAF(g_root, 2, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A))
  /* VS-stage bare: vsatp = 0, so only the G-stage applies to HLV/HLVX. */
  csrw vsatp, zero
  hfence.vvma
  HGATP_ON

  /* Make sure MXR is clear (it would legitimately allow X-as-R). */
  li t0, (1 << 19)
  csrc mstatus, t0
  /* HLV/HLVX executed with effective privilege VS (SPVP=1). */
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  la s0, data_word
  li s2, 0              /* step marker: 0 = HLVX, 1 = HLV */

  /* 1) HLVX.WU from the execute-only page: must succeed and fill the DTLB. */
  hlvx.wu s1, (s0)
  li t0, 0x5a5aa5a5
  bne s1, t0, fail_hlvx_val

  /* 2) Plain HLV.W from the same page: must raise load guest-page fault. */
  li s2, 1
hlv_insn:
  hlv.w s3, (s0)
  /* Reaching here means the load succeeded: bug. */
  FAIL(1)

fail_hlvx_val:
  FAIL(2)

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t0, t1, bad_trap
  beqz s2, hlvx_trapped        /* HLVX must not fault */
  csrr t0, mepc
  la t1, hlv_insn
  bne t0, t1, bad_trap
  PASS
hlvx_trapped:
  FAIL(3)
bad_trap:
  FAIL(4)

  .data
  .align 3
data_word: .word 0x5a5aa5a5
  .word 0

  HYP_TABLES
