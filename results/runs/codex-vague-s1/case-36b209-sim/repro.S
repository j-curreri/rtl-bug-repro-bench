#include "hyp.h"

/*
 * Check exception priority for a store hitting a cached two-stage translation.
 *
 * VA 0x40000000 -> GPA 0xc0000000 -> PA 0x80000000 is read-only at
 * BOTH stages.  A load is legal and populates the DTLB.  The subsequent
 * store must fail at the VS stage (mcause=15), before the final G-stage
 * translation can produce a store guest-page fault (mcause=23).
 * Code and the VS page table have separate, fully accessible mappings.
 */
  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  csrw medeleg, zero
  csrw mideleg, zero
  csrw satp, zero
  csrw vsstatus, zero

  /* Identity map DRAM for guest instructions and VS page-table reads. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* Readable, accessed, dirty, but not writable at either stage. */
  GIGA_LEAF(vs_root, 1, 0xc0000000, (PTE_V | PTE_R | PTE_A | PTE_D))
  GIGA_LEAF(g_root, 3, 0x80000000, (PTE_V | PTE_R | PTE_U | PTE_A | PTE_D))

  fence rw, rw
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  ENTER_VS(guest)

guest:
  li s0, 0x40000000
  ld t2, 0(s0)                 /* Fill DTLB with a legal load. */
  fence rw, rw
  .globl faulting_store
faulting_store:
  sd zero, 0(s0)
  FAIL(1)                     /* The store must trap. */

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 15                   /* Store/AMO page fault, not guest-page fault. */
  bne t0, t1, wrong_cause
  csrr t0, mepc
  la t1, faulting_store
  bne t0, t1, wrong_pc
  csrr t0, mtval
  li t1, 0x40000000
  bne t0, t1, wrong_address
  PASS

wrong_cause:
  FAIL(2)
wrong_pc:
  FAIL(3)
wrong_address:
  FAIL(4)

  HYP_TABLES
