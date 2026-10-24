/* Guest-page-fault mtval2 on a DTLB hit through a VS-stage gigapage.
 *
 * VS-stage: VA 0x40000000 -> GPA 0xC0000000 (1 GiB leaf, RWX).
 * G-stage:  GPA 0xC0000000 -> PA 0x80000000 (1 GiB leaf, read-only).
 * A load from VA 0x40123458 fills the TLB; a store to the same address then
 * raises a store guest-page fault (cause 23) on the TLB hit path. The spec
 * requires mtval = VA and mtval2 = GPA >> 2 = 0xC0123458 >> 2.
 * The buggy TLB drops GPA bit 30 for S-stage gigapages (reports 0x80123458).
 */
#include "hyp.h"

#define G_RO (PTE_V | PTE_R | PTE_U | PTE_A | PTE_D)
#define TEST_VA  0x40123458
#define TEST_GPA 0xC0123458

  .option norvc
  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: identity for code/data, read-only alias at GPA 0xC0000000 */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, G_RO)
  /* VS-stage: identity for code/data, VA 0x40000000 -> GPA 0xC0000000 */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 1, 0xC0000000, VS_RWX)
  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)
  li s11, 0
  ENTER_VS(vs_code)

vs_code:
  li a0, TEST_VA
  /* loads are allowed: fill the TLB */
  ld a1, 0(a0)
  ld a1, 0(a0)
  bnez s11, fail_load
  /* store hits the TLB and must raise a store guest-page fault */
  sd a1, 0(a0)
  li t0, 23
  bne s11, t0, fail_cause
  bne s10, a0, fail_tval
  li t0, (TEST_GPA >> 2)
  bne s9, t0, fail_tval2
  PASS
fail_load:
  FAIL(1)
fail_cause:
  FAIL(2)
fail_tval:
  FAIL(3)
fail_tval2:
  FAIL(4)

/* Record mcause/mtval/mtval2 and skip the faulting (4-byte) instruction. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr s11, mcause
  csrr s10, mtval
  csrr s9, mtval2
  csrr t6, mepc
  addi t6, t6, 4
  csrw mepc, t6
  mret

  HYP_TABLES
