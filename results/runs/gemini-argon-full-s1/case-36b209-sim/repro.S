#include "hyp.h"

#define CAUSE_LOAD_GUEST_PAGE_FAULT 21

/* Valid Sv39 non-leaf PTE (V=1, R=W=X=U=G=A=D=0, RSW=0, reserved[63:54]=0)
 * with PPN = (1 << 29), pointing to next-level page table at GPA = (1 << 41).
 * Under Sv39x4 (41-bit GPA space, bits 63:41 must be 0), translating this
 * non-leaf pointer's target GPA must raise a load guest-page fault (cause 21). */
#define NONLEAF_OOB_GPA_PTE ((1 << 39) | PTE_V)

#define TEST_GVA 0x40000000

  .text
  .globl test_main
  .balign 4
test_main:
  csrci mstatus, 8
  PMP_ALLOW_ALL

  csrw medeleg, zero
  csrw hedeleg, zero
  li t0, 2
  csrc vsstatus, t0

  /* Identity-map 1 GiB [0x80000000, 0xc0000000) in both G-stage and VS-stage
   * so VS-mode code execution and VS-stage root page-table walks succeed. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* Map GVA [0x40000000, 0x80000000) (VPN[2] = 1) with a non-leaf PTE pointing
   * outside the 41-bit guest-physical address space. */
  RAW_PTE(vs_root, 1, NONLEAF_OOB_GPA_PTE)

  fence rw, rw
  HGATP_ON
  la a0, vs_root
  VSATP_ON(a0)

  ENTER_VS(vs_entry)

  .balign 4
vs_entry:
  li a0, TEST_GVA
faulting_load:
  ld t0, 0(a0)
  FAIL(2)

  .globl trap_handler
  .balign 64
trap_handler:
  csrr t0, mepc
  la t1, faulting_load
  bne t0, t1, unexpected_trap

  csrr t0, mcause
  li t1, CAUSE_LOAD_GUEST_PAGE_FAULT
  bne t0, t1, wrong_cause

  PASS

unexpected_trap:
  FAIL(1)

wrong_cause:
  FAIL(3)

  HYP_TABLES
