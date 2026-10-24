/* repro.S — CVA6 bug reproducer (two-stage VS load, out-of-range non-leaf PTE)
 *
 * Bug: in VS-mode with two-stage translation, when the VS-stage walk reaches a
 * non-leaf PTE whose implied guest-physical address is outside the GPA space
 * (pte.ppn[43:29] != 0), cva6_ptw.sv enters PROPAGATE_ERROR with ptw_stage_d =
 * ptw_stage_q (still S_STAGE; see the non-leaf branch, ~line 598 — the leaf
 * branch correctly uses G_FINAL_STAGE). The MMU then selects the exception
 * cause from ptw_error_at_g_st == 0 and reports LOAD_PAGE_FAULT (13) instead
 * of the spec-required LOAD_GUEST_PAGE_FAULT (21).
 *
 * Test: run a VS-mode load through a VS 1 GiB leaf that maps everything fine
 * (sanity: must NOT trap on any core). Then run a VS-mode load at a VA whose
 * root-level VS PTE is a non-leaf pointing outside the guest-physical address
 * space. On a correct core that load traps with cause 21 -> PASS. On this
 * buggy core it traps with cause 13 -> FAIL(2).
 */

#include "hyp.h"

  .text
  .globl test_main
test_main:
  /* Make all of DRAM accessible below M-mode. */
  PMP_ALLOW_ALL

  /* ---- G-stage (SV39x4): 1 GiB leaves only --------------------------------
   * g_root[0]: GPA 0x00000000-0x3FFFFFFF -> HPA 0x80000000+offset
   * g_root[2]: GPA 0x80000000-0xBFFFFFFF -> identity (code + tables page)   */
  GIGA_LEAF (g_root, 0, 0x80000000, G_RWX)
  GIGA_LEAF (g_root, 2, 0x80000000, G_RWX)

  /* ---- VS-stage (SV39) -----------------------------------------------------
   * vs_root[0]: TRIGGER — non-leaf PTE whose PPN has bit 43 set.  The implied
   *             GPA (ppn << 12 = 2^55) lies far outside the 41-bit
   *             guest-physical address space.
   * vs_root[1]: VA 0x40000000-0x7FFFFFFF -> GPA 0x00000000+offset (data page)
   * vs_root[2]: VA 0x80000000-0xBFFFFFFF -> GPA 0x80000000+offset; identity
   *             mapping so VS-mode instruction fetches keep working.          */
  RAW_PTE  (vs_root, 0, PTE_V | (1 << 53))
  GIGA_LEAF(vs_root, 1, 0x0, VS_RWX)
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* Enable both stages (VMID/ASID 0, full hfences). */
  HGATP_ON

  /* vsatp takes the VS root at its GUEST-physical address:
   * GPA(vs_root) = HPA(vs_root) - 0x80000000 (guaranteed < 2^30 here). */
  la   t0, vs_root
  li   t1, 0x80000000
  sub  t0, t0, t1
  VSATP_ON(t0)

  /* VA that maps onto `magic` through vs_root[1] + g_root[0]. */
  la   t0, magic
  sub  t0, t0, t1     /* t1 is still 0x80000000 */
  li   s0, 0x40000000
  or   s0, s0, t0

  /* Enter VS-mode. */
  ENTER_VS(vs_code)

/* Executing in VS-mode now.  All fetches go through vs_root[2] + g_root[2]. */
vs_code:
  /* Sanity: a load through an entirely valid VS/G 1 GiB mapping must work
   * (both cores must reach the trigger). */
  ld   a1, 0(s0)
  li   a5, 0x600dc0de
  bne  a1, a5, fail_sanity

  /* Trigger: VA 0x1000 has VS root index 0 -> the out-of-range non-leaf PTE.
   * A spec-correct core traps here with LOAD_GUEST_PAGE_FAULT (21). */
  li   t0, 0x1000
  ld   t1, 0(t0)
  FAIL(3)             /* unreachable if the walk faults; safety net */

fail_sanity:
  FAIL(1)

/* Trap target (DEBUG round 1: tohost = (mepc << 8) | (mcause << 1) | 1). */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  csrr t1, mepc
  slli t5, t1, 8
  slli t0, t6, 1
  ori  t5, t5, 1
  or   t5, t5, t0
  la   t3, tohost
  sd   t5, 0(t3)
1: j 1b

  .data
  .globl magic
magic:
  .word 0x600dc0de

  HYP_TABLES