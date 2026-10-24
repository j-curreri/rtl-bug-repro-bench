/* repro.S — bare-metal reproducer for the hypervisor TLB bug in cva6_mmu.sv.
 *
 * Bug: after an HLVX load fills the DTLB with a G-stage translation whose leaf
 * is execute-only (V|X|U|A|D, no R), a plain HLV load at the same guest
 * address hits that cached entry.  The DTLB-hit path only re-checks the G-pte
 * U bit (d_g_st_access_err); g_load_access_ok — which encodes "R, or X treated
 * as R" — is computed in cva6_mmu.sv but never used in the load branch, so the
 * execute-only page is accepted for a plain read.  A spec-correct core must
 * raise a load guest-page fault (cause 21) there, since only HLVX may use
 * execute permission as read permission.
 *
 * Sequence (all in HS-mode, G-stage only):
 *   1. M-mode: install a 1 GiB execute-only G-leaf at g_root[1] (hgatp Sv39x4,
 *      VMID 0), then mret into HS-mode with hstatus.SPVP = 0 and vsatp bare.
 *      With SPVP = 0 an HLV address is a guest-physical address and is
 *      translated by the G-stage alone.
 *   2. HLVX.WU from that guest page - misses, walks, fills the DTLB entry
 *      (the walker permits HLVX on X-only leaves).  No fences or CSR changes
 *      after this point, so the entry stays cached.
 *   3. Plain HLV.WU at the same guest address:
 *        - corrected core: hit path rejects the read (R=0, X-only, MXR=0,
 *          not HLVX) -> trap, mcause = 21 (LOAD_GUEST_PAGE_FAULT) -> PASS.
 *        - buggy core: no G-permission re-check -> load returns data -> FAIL.
 *
 * mcause 21 matches riscv_pkg.sv: LOAD_GUEST_PAGE_FAULT = 'd21.
 * Phases are tracked in s2: 0 setup, 1 HLVX in flight, 2 plain HLV in flight.
 * The trap handler passes only a cause-21 trap taken while phase 2 is active;
 * every trap in any other phase or with any other cause is a failure, so a
 * mis-built setup cannot produce a false PASS.
 */

#include "test.h"
#include "hyp.h"

  .text
  .globl test_main
test_main:
  li s2, 0

  PMP_ALLOW_ALL

  /* Belt-and-braces CSR state for the HLV path: no MXR, no HU, bare satp. */
  li t0, (1 << 19)               /* mstatus.MXR */
  csrc mstatus, t0
  li t0, (3 << 6)                /* hstatus.HU | hstatus.SPVP */
  csrc hstatus, t0
  csrw satp, x0
  csrw vsatp, x0

  /* Build the G-stage root: entry 1 = 1 GiB execute-only leaf.
   * PTE = PA 0x80000000 (ppn = 2 << 18 | PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
   *     = 0x200000D9, R = W = 0.  Maps gpa[41:30]==1 (0x4xxxxxxxx) to PA
   * 0x80000000-0xBFFFFFFF.  */
  RAW_PTE(g_root, 1, 0x200000D9)
  HGATP_ON                       /* hgatp = Sv39x4, VMID 0, root g_root */

  ENTER_MODE(1, hs_main)         /* mret into HS-mode, V = 0 */

  /* Unreachable: ENTER_MODE jumps away. */
  FAIL(4)

  /* -------------------------------------------------------------- */
  /* HS-mode: G-stage translation enabled, VS-stage off (vsatp=0).  */
  /* -------------------------------------------------------------- */
.align 2
hs_main:
  /* Guest address of hvv_data: gpa = pa - 0x40000000, so gpa[41:30] = 1. */
  la t1, hvv_data
  li t2, 0x40000000
  sub t1, t1, t2

  /* 1. HLVX.WU from the exec-only guest page: must succeed (X is enough for
   *    HLVX) and, as a side effect, fills the DTLB with the cached G-leaf.  */
  li s2, 1
  hlvx.wu t3, 0(t1)

  /* 2. Plain HLV.WU at the same address, same translation context, no fences
   *    or CSR changes in between: must raise a load guest-page fault.  */
  li s2, 2
  hlv.wu t5, 0(t1)

  /* Only reached on a buggy core, where the plain load returned data.  */
  FAIL(1)

/* Traps land here in M-mode (no delegation set).  Exactly one trap is legal:
 * a load guest-page fault (mcause = 21) taken while the plain HLV is in
 * flight (s2 = 2) - that is the spec-correct behavior under test.  */
.align 2
.globl trap_handler
trap_handler:
  csrr t6, mcause
  li t0, 21                      /* LOAD_GUEST_PAGE_FAULT */
  bne t6, t0, fail2
  li t0, 2
  bne s2, t0, fail2
  PASS                           /* a0=1 -> simulation success */
fail2:
  FAIL(2)

  .data
  .align 3
  /* Address anchor only; its contents are never read. */
hvv_data:
  .word 0
  .align 14                      /* G-stage root must be 16 KiB aligned:    */
g_root:                          /*   hgatp.ppn[1:0] is ignored by the PTW,  */
  .space 16384                   /*   the walk re-splices gpa[41:30].        */