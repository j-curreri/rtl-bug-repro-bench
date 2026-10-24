/* Reproducer: G-stage permission not enforced on hypervisor virtual-machine loads.
 *
 * The CVA6 MMU computes the G-stage read-permission for a load hit
 * (g_load_access_ok = dtlb_gpte_q.r || (dtlb_gpte_q.x && (mxr|hlvx))) but never
 * uses it on the DTLB-hit load path.  As a result, a plain HLV load that hits a
 * TLB entry previously filled by an HLVX (execute-as-read) access inherits the
 * execute-only G-stage permission and is wrongly allowed.
 *
 * Scenario (all executed in M-mode, HLV / HLVX force two-stage VS+G translation):
 *   - VS-stage: VA 0xC0000000 -> GPA 0xC0000000, perms R+W+X (so both HLVX and
 *     a plain read pass the FIRST stage).
 *   - G-stage : GPA 0xC0000000 -> PA 0x80000000, perms X-only (R=0), U=1 (so the
 *     G-stage U check passes but read permission is absent).
 *   1. HLVX.WU fills the TLB legitimately (execute-only page is readable-as-exec).
 *   2. HLV.D then hits that entry. A spec-correct core must re-check G-stage read
 *      permission and raise a load guest-page fault (mcause 21).  The buggy core
 *      skips the check and completes the load.
 *
 * Correct core: HLV.D traps with cause 21 -> PASS.
 * Buggy core  : HLV.D completes, no trap  -> FAIL(1).
 */

#include "hyp.h"

/* G-stage execute-only leaf: V|X|U|A|D (no R, no W). */
#define G_XONLY (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* ---- Build G-stage (Sv39x4) 1 GiB leaves ---- */
  /* GPA [0x80000000,0xC0000000) -> PA 0x80000000, full RWX (holds code + page
     tables; needed so the implicit VS-stage page-table reads succeed). */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  /* GPA [0xC0000000,0x100000000) -> PA 0x80000000 (alias), execute-only. */
  GIGA_LEAF(g_root, 3, 0x80000000, G_XONLY)

  /* ---- Build VS-stage (Sv39) 1 GiB leaf ---- */
  /* VA 0xC0000000 -> GPA 0xC0000000, RWX (first stage permits read and exec). */
  GIGA_LEAF(vs_root, 3, 0xC0000000, VS_RWX)

  /* ---- Turn on translation ---- */
  HGATP_ON
  la   t2, vs_root          /* vs_root GPA == PA (identity in GiB 2) */
  VSATP_ON(t2)

  /* Effective privilege of HLV / HLVX is hstatus.SPVP; use VS (supervisor). */
  li   t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* Target virtual address. */
  li   a0, 0xC0000000

  /* 1. HLVX: legitimately fills the TLB (read-as-execute on X-only page). */
  hlvx.wu a1, (a0)

  /* 2. Plain HLV load: must fault on a correct core (G-stage has no read perm). */
  hlv.d   a2, (a0)

  /* Reached only on the buggy core (load wrongly succeeded). */
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  li   t5, 21                /* LOAD_GUEST_PAGE_FAULT */
  beq  t6, t5, 1f
  mv   a0, t6                /* unexpected trap: report mcause for debugging */
  slli a0, a0, 1
  ori  a0, a0, 1
  j    _halt
1:
  PASS

  HYP_TABLES
