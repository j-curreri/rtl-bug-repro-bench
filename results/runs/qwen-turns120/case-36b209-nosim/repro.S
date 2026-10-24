/* Reproducer for CVA6 two-stage-translation exception-cause bug.
 *
 * Bug: in VS-mode with two-stage translation, a load whose VS-stage walk reaches a
 * non-leaf PTE pointing outside the guest-physical address space is reported with
 * the wrong exception cause. The RISC-V spec requires a guest-page fault (cause 21
 * for a load); this core reports a regular load page fault (cause 13).
 *
 * Setup:
 *   - G-stage (hgatp, Sv39): one 1GiB leaf in g_root that maps the DRAM region
 *     containing the tables to itself (identity), so the G walk always succeeds.
 *   - VS-stage (vsatp, Sv39): vs_root[0] is a NON-LEAF PTE whose PPN lies outside
 *     the 41-bit guest-physical space (PPN bit 29 set).
 *   - A load in VS-mode from a vaddr whose top index is 0 makes the VS walk read
 *     vs_root[0]; the walker's out-of-guest-physical-range check on that non-leaf
 *     PTE is what the bug corrupts.
 *
 * On a spec-compliant core the load raises LOAD_GUEST_PAGE_FAULT (21) -> PASS.
 * On the buggy core it raises LOAD_PAGE_FAULT (13) (or another wrong cause) -> FAIL.
 */
#include "hyp.h"

  .globl test_main
  .globl trap_handler

  .section .text
  .align 2

test_main:
  PMP_ALLOW_ALL

  /* ---- G stage: identity 1GiB mapping of the 1GiB region holding the tables ----
   * G root index for a GPA is GPA[38:30]; a 1GiB leaf there maps the whole region.
   * vs_root and g_root both live just above 0x80000000, in the same 1GiB region. */
  la    t0, vs_root            /* t0 = guest-physical address of the VS root table */
  srli  t1, t0, 30             /* t1 = G root index = t0[38:30] */
  slli  t2, t1, 30             /* t2 = base of that 1GiB region */
  srli  t2, t2, 12             /* t2 = PPN of the 1GiB region */
  slli  t2, t2, 10             /* t2 = PPN << 10 */
  li    t3, G_RWX              /* t3 = V|R|W|X|U|A|D */
  or    t2, t2, t3             /* t2 = 1GiB leaf PTE */
  slli  t1, t1, 3              /* t1 = index*8 (byte offset into g_root) */
  la    t3, g_root
  add   t3, t3, t1             /* t3 = &g_root[idx] */
  sd    t2, 0(t3)              /* g_root[idx] = 1GiB identity leaf */

  /* ---- VS stage: root PTE[0] = non-leaf PTE pointing outside the GPA space ----
   * PPN = 1<<29, so pte.ppn[43:29] is non-zero (guest-physical address >= 2^41).
   * V=1, R=W=X=0 -> a pointer PTE, not a leaf. */
  la    t0, vs_root
  li    t1, (1 << 39) | 1      /* PTE = (1<<29)<<10 | V */
  sd    t1, 0(t0)             /* vs_root[0] */

  /* ---- enable translation, enter VS mode ---- */
  HGATP_ON                     /* G-stage on (hgatp root = g_root) */
  la    t0, vs_root
  VSATP_ON(t0)                /* VS-stage on (vsatp root = vs_root) */
  ENTER_VS(vs_load)

vs_load:
  /* Fault the load. vaddr top index is 0, so the VS walk consults vs_root[0]. */
  li    t0, 0x1000
  ld    t1, 0(t0)            /* raises the (wrong-cause on buggy RTL) page fault */
  /* If we got here the walk did not fault -> the scenario was not triggered. */
  li    a0, (2 << 1) | 1
  j     _halt

  /* M-mode trap handler. With medeleg/hedeleg = 0 a VS-mode page fault is taken in
   * M-mode, so mcause holds the original cause here. */
  .align 2
trap_handler:
  csrr  t0, mcause
  li    t1, 21               /* LOAD_GUEST_PAGE_FAULT */
  beq   t0, t1, repro_pass
  FAIL(1)                    /* wrong cause (buggy RTL) */
repro_pass:
  PASS                       /* spec-compliant cause */

HYP_TABLES
