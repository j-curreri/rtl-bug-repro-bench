/* G-stage translation must treat every access as a U-mode access, including the
 * implicit reads of VS-stage page tables (priv. spec, H extension, "Two-Stage
 * Address Translation"). A G-stage leaf with U=0 that maps a VS-level page table
 * must therefore raise a guest-page fault when the VS-stage walk reads it.
 *
 * Setup (M-mode, accesses via HLV.D so they go through VS+G translation):
 *   G-stage : GPA 0x80000000 1 GiB -> PA 0x80000000, U=1 (code, data, vs_root)
 *             GPA 0x40000000 1 GiB -> PA 0x80000000, U=0 (alias used for vs_l1)
 *   VS-stage: vs_root[0] -> non-leaf at GPA alias of vs_l1 (inside the U=0 page)
 *             vs_l1[0]   -> 2 MiB leaf VA 0 -> GPA 0x80000000
 * HLV.D from VA 0 must take a load guest-page fault (cause 21) while reading vs_l1.
 * The buggy PTW does not check U on G-stage leaves for VS page-table accesses.
 */
#include "hyp.h"

#define CAUSE_LOAD_GUEST_PF 21

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL
  li t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* G-stage */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 1, 0x80000000, (G_RWX & ~PTE_U))

  /* vs_root[0] -> GPA (vs_l1 - 0x80000000 + 0x40000000), a non-leaf pointer */
  la t0, vs_l1
  li t1, 0x80000000
  sub t0, t0, t1
  li t1, 0x40000000
  add t0, t0, t1
  srli t0, t0, 12
  slli t0, t0, 10
  ori t0, t0, PTE_V
  la t1, vs_root
  sd t0, 0(t1)

  /* vs_l1[0] -> 2 MiB leaf, VA 0 -> GPA 0x80000000 */
  RAW_PTE(vs_l1, 0, ((0x80000000 >> 12) << 10) | VS_RWX)

  sfence.vma
  HGATP_ON
  la t2, vs_root
  VSATP_ON(t2)

  /* 1) VS page table lives in a G-stage page with U=0: must fault (cause 21) */
  la s10, 1f
  li s11, 0
  li a1, 0
  hlv.d a2, (a1)
1:
  li t0, CAUSE_LOAD_GUEST_PF
  beq s11, t0, 2f
  FAIL(1)
2:
  /* 2) Sanity: same walk with U=1 on that G-stage page succeeds */
  GIGA_LEAF(g_root, 1, 0x80000000, G_RWX)
  hfence.gvma
  hfence.vvma
  la s10, 4f
  li s11, 0
  li a1, 0
  hlv.d a2, (a1)
4:
  beqz s11, 5f
  FAIL(3)
5:
  la t0, _start
  ld t1, 0(t0)
  beq a2, t1, 6f
  FAIL(4)
6:
  PASS

/* Record the trap and resume at s10 (M-mode). */
  .align 2
  .globl trap_handler
trap_handler:
  csrr s11, mcause
  jr s10

  HYP_TABLES
  .align 12
vs_l1: .space 4096
