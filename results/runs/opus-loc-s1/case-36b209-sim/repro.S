/* Reproducer for cva6_ptw.sv: implicit G-stage checks on VS-stage page-table walks.
 *
 * Per the H extension, G-stage translation treats every access (including the
 * implicit reads of VS-stage page tables) as a U-mode access, and a VS-stage
 * non-leaf PTE pointing at a guest-physical address with bits 63:41 set must
 * fail G-stage (Sv39x4) translation with a guest-page fault, not a page fault.
 *
 * Check 1: the VS page table lives in a G-stage page with U=0 while the final
 *          data page has U=1 -> HLV.D must raise a load guest-page fault (21).
 * Check 2: a VS non-leaf PTE points to GPA 2^41 -> HLV.D must raise cause 21.
 *
 * A spec-correct core passes both checks. This buggy core passes neither: it
 * silently completes check 1 and reports cause 13 in check 2. PASS requires at
 * least one check to behave correctly. */
#include "hyp.h"

  .text
  .globl trap_handler
  .align 2
trap_handler:
  csrr s1, mcause
  csrr t0, mepc
  addi t0, t0, 4          /* hlv.d is a 4-byte instruction */
  csrw mepc, t0
  mret

  .globl test_main
test_main:
  PMP_ALLOW_ALL
  /* G-stage: GPA 1-2 GiB (code, data, VS tables) -> PA 0x80000000, U=0;
   *          GPA 3 GiB -> PA 0x80000000, U=1. */
  GIGA_LEAF(g_root, 2, 0x80000000, (G_RWX & ~PTE_U))
  GIGA_LEAF(g_root, 3, 0x80000000, G_RWX)
  /* VS-stage: VA 3 GiB -> GPA 3 GiB; VA 1 GiB -> non-leaf at GPA 2^41. */
  GIGA_LEAF(vs_root, 3, 0xC0000000, VS_RWX)
  RAW_PTE(vs_root, 1, (((1 << 29) << 10) | PTE_V))
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Check 1: VS page-table read through a G-stage page without U. */
  li s1, 0
  li t0, 0xC0000000
  .option push
  .option norvc
  hlv.d a1, (t0)
  .option pop
  bnez s1, pass           /* any trap here means the U bit was checked */

  /* Check 2: VS non-leaf pointer outside the Sv39x4 guest-physical space. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  hfence.gvma
  hfence.vvma
  li s1, 0
  li t0, 0x40000000
  .option push
  .option norvc
  hlv.d a1, (t0)
  .option pop
  li t0, 21               /* load guest-page fault */
  beq s1, t0, pass
  FAIL(1)
pass:
  PASS

  HYP_TABLES
