/*
 * Bug: in VS-mode with two-stage translation, a load whose VS-stage walk reaches a
 * NON-LEAF PTE pointing outside the guest-physical address space must raise a
 * LOAD_GUEST_PAGE_FAULT (cause 21).  This buggy core reports a plain
 * LOAD_PAGE_FAULT (cause 13) instead.
 *
 * Root cause (core/cva6_mmu/cva6_ptw.sv, PTE_LOOKUP, non-leaf PTE branch):
 *   the "PTE points outside the guest-physical address space" check sets
 *       ptw_stage_d = ptw_stage_q;            // = S_STAGE   (BUG)
 *   whereas the identical check in the leaf-PTE branch correctly sets
 *       ptw_stage_d = G_FINAL_STAGE;
 *   PROPAGATE_ERROR then computes ptw_error_at_g_st = (ptw_stage_q != S_STAGE),
 *   so the buggy S_STAGE value makes the MMU emit LOAD_PAGE_FAULT (13) rather
 *   than LOAD_GUEST_PAGE_FAULT (21).
 *
 * Setup:
 *   - G-stage (Sv39x4) root has a single 1 GiB identity leaf mapping the physical
 *     region [0x80000000,0xC0000000) (G-root index 2), so every guest-physical
 *     address of the VS-stage tables and of the code itself resolves.
 *   - VS-stage (Sv39) root:
 *        index 2 = 1 GiB identity leaf [0x80000000,0xC0000000)  -> lets the
 *                VS-mode code and its page-table fetches execute;
 *        index 1 = a NON-LEAF PTE (V only, A=D=U=0) whose PPN has bit 30 set
 *                (PPN[43:29] != 0) -> points OUTSIDE the 41-bit GPA space.
 *   - In VS-mode, `ld` at a virtual address with va[38:30]==1 walks to that
 *     out-of-range non-leaf PTE in the VS stage and must trap with cause 21.
 *
 * On a correct core: mcause == 21 -> PASS.
 * On this buggy core: mcause == 13 -> FAIL.
 */
#include "test.h"
#include "hyp.h"

  HYP_TABLES

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage: 1 GiB identity leaf for [0x80000000,0xC0000000) at G-root index 2. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* VS-stage root level-2 index 2: 1 GiB identity leaf for the code/data region
   * [0x80000000,0xC0000000) so instruction fetches resolve under two-stage. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)

  /* VS-stage root level-2 index 1: NON-LEAF PTE pointing outside the GPA space.
   * PTE = V | (1 << 40): bit 40 is PPN bit 30, inside PPN[43:29] (PPNW=44,
   * GPPNW=29).  A=D=U=0 and reserved bits clear -> a valid non-leaf PTE. */
  RAW_PTE(vs_root, 1, 0x10000000001)

  HGATP_ON
  la t0, vs_root
  VSATP_ON(t0)

  ENTER_VS(vs_load)

/* ---- executes in VS-mode with two-stage translation active ---- */
vs_load:
  li t0, 0x40000000           /* va[38:30] == 1 -> selects the out-of-range PTE */
  ld t1, 0(t0)               /* must raise LOAD_GUEST_PAGE_FAULT (cause 21) */
1: j 1b                      /* unreachable: the load always traps */

  .align 2
  .globl trap_handler
trap_handler:
  csrr t0, mcause
  li t1, 21                  /* LOAD_GUEST_PAGE_FAULT */
  bne t0, t1, repro_fail
  PASS
repro_fail:
  FAIL(2)
