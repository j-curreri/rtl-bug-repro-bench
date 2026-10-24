/*
 * Bug reproducer: G-stage DTLB-hit permission leak in cva6_mmu.
 *
 * Bug: after an HLVX instruction has translated a guest page that is
 * execute-only at the G-stage (X=1, R=0), the DTLB holds that page's
 * translation. A later plain HLV load from the same page then hits in
 * the DTLB, and the hit path only re-checks the G-stage U bit - it does
 * not re-check the G-stage R/X permission against the current access
 * type.  The plain HLV therefore succeeds where the spec requires a
 * load guest-page fault (cause 21), because only HLVX (or MXR) may
 * treat execute permission as read permission.
 *
 * The reproducer therefore relies on the DTLB being *warm*: the first
 * access must be an HLVX (which is legal on an execute-only G-page and
 * populates the DTLB), so that the *second*, plain HLV access takes the
 * buggy DTLB-hit path.  A cold plain HLV would correctly fault at the
 * page-table-walk permission check on any core, so it would not expose
 * the bug.
 *
 * Test, run in M-mode: HS load/store virtual instructions (HLVX/HLV)
 * perform two-stage translation using VSATP + HGATP and execute with
 * privilege hstatus.SPVP (= S here).  (Code/tables/stack stay at
 * VA=PA=0x80000000, which is not translated for M-mode itself.)
 *
 *   G-stage (Sv39x4) root g_root:
 *     idx 2 (GPA 0x8000_0000): 1 GiB RWX leaf -> HPA 0x8000_0000 (code)
 *     idx 3 (GPA 0x8400_0000): 1 GiB X-only leaf -> HPA 0x8000_0000
 *   VS-stage (Sv39) root vs_root:
 *     idx 2 (VA 0x8000_0000): 1 GiB RWX leaf -> GPA 0x8000_0000
 *     idx 3 (VA 0x8400_0000): 1 GiB RWX leaf -> GPA 0x8400_0000
 *
 *   hlvx.wu on VA 0x8400_0000 : legal on any conforming core (X as read);
 *                               also warms the DTLB for that VA.
 *   HLV_W   on VA 0x8400_0000 : plain guest load; must raise a load
 *                               guest-page fault (mcause = 21).
 *
 * Correct core: the plain load traps, trap_handler verifies cause + PC
 * and mrets to PASS.  Buggy core: the plain load hits the (buggy) DTLB
 * path and silently succeeds, so control falls through to FAIL(1).
 */
#include "hyp.h"

  .section .text
  .globl test_main
test_main:
  /* PTW page-table reads are PMP-checked as S-mode loads. */
  PMP_ALLOW_ALL

  /* G-stage root: two 1 GiB leaves.  The execute-only leaf's HPA points
   * into valid DRAM (0x8000_0000) so a load that (wrongly) passes the
   * permission check can actually be serviced. */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)
  GIGA_LEAF(g_root, 3, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)

  /* VS-stage root: identity 1 GiB leaves. */
  GIGA_LEAF(vs_root, 2, 0x80000000, VS_RWX)
  GIGA_LEAF(vs_root, 3, 0x84000000, VS_RWX)

  /* HS load/stores execute as S-mode guest accesses (SPVP = 1). */
  li   t0, HSTATUS_SPVP
  csrs hstatus, t0

  HGATP_ON
  la   t0, vs_root          /* VSATP_ON clobbers t0: it must hold the root address */
  VSATP_ON(t0)

  li   a0, 0x84000000
  hlvx.wu x0, 0(a0)      /* execute-only as read: permitted on any core;
                            warms the DTLB for VA 0x8400_0000 */
faulting_hlw:
  /* HLV_W x1, (a0): plain 32-bit guest load, same VA.  New H-ext
   * encoding: opcode=0x73, funct3=4, funct7=0x34, rs2=0, rs1=a0, rd=x1.
   * (This toolchain has no plain-loads mnemonic, so emit the word.) */
  .word 0x680540f3
  /* Reaching this point means the plain HLV wrongly succeeded: the bug. */
  FAIL(1)

  .align 2
.globl trap_handler
trap_handler:
  csrr t0, mcause
  li   t1, 21            /* LOAD_GUEST_PAGE_FAULT */
  bne  t0, t1, trap_fail
  csrr t0, mepc
  la   t1, faulting_hlw
  bne  t0, t1, trap_fail
  /* The expected fault: resume with PASS. */
  la   t0, got_expected_fault
  csrw mepc, t0
  mret
trap_fail:
  FAIL(127)

got_expected_fault:
  PASS

HYP_TABLES
