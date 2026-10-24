#include "hyp.h"

/*
 * Bug: after an HLVX reads a G-stage page that is mapped execute-only, a
 * plain HLV load from the same page also succeeds.  The load should raise a
 * load guest-page fault, because only HLVX may treat execute permission as
 * read permission.
 *
 * Root cause (cva6_mmu.sv, DTLB-hit data path): `g_load_access_ok` is
 * computed (`dtlb_gpte_q.r || dtlb_gpte_q.x && (mxr_i || hlvx_inst_q)`) but is
 * never applied to loads.  A G-stage translation cached in the DTLB by a prior
 * HLVX therefore lets a later plain load through even though the cached G PTE
 * has r=0/x=1.  The PTW path (first access) checks permissions correctly, so
 * the bug only shows up when the second access is a DTLB *hit*.
 *
 * Sequence (S-mode, G-stage on, VS/S-stage off so GVA == GPA):
 *   1. hlvx load of an execute-only G page -> succeeds, fills the DTLB.
 *   2. plain HLV load of the same page -> hits the DTLB.
 *        - correct core: g_load_access_ok == 0  => load guest-page fault.
 *        - buggy core  : no re-check            => load succeeds (FAIL).
 *
 * A correct core traps (cause 21, load guest-page fault) on step 2 -> PASS.
 * This buggy core lets step 2 through -> reaches FAIL(2).
 */

HYP_TABLES

  .section .data
  .align 4
stage: .dword 0      /* 0 = hlvx not yet done, 1 = hlvx completed without trap */

  .section .text
  .globl test_main
test_main:
  /* ---- M-mode setup ---- */
  PMP_ALLOW_ALL
  /* G-stage: 1GiB execute-only leaf at root index 2 -> HPA 0x80000000.
   *   PTE = V|X|U|A (0x59): execute-only, user, accessed; no R/W/D. */
  GIGA_LEAF(g_root, 2, 0x80000000, 0x59)
  /* VS-stage and S-mode stage off: the GVA is used directly as a GPA. */
  li t0, 0
  csrw vsatp, t0
  li t0, 0
  csrw satp, t0
  /* Enable G-stage translation (VMID 0, Sv39). */
  HGATP_ON
  /* H-extension loads only run in S/HS mode. */
  ENTER_MODE(1, s_entry)

s_entry:
  /* ---- S-mode ---- */
  la t0, s_trap
  csrw stvec, t0
  li t1, 0x20080000          /* GVA == GPA; maps to HPA 0x80080000 */
  /* HLVX (execute-as-read) load: must succeed, and populates the DTLB. */
  hlvx.wu t2, (t1)
  li t0, 1
  la t3, stage
  sd t0, 0(t3)              /* stage = 1 (hlvx retired without trapping) */
  /* Plain HLV load from the same page: must fault.
   *  HLV_W with rs1=t1(x6), rd=t4(x12):
   *  opcode=0x73 funct3=100 funct7=0110100 rs2=0 -> 0x68034673 */
  .word 0x68034673
  /* Reached only if the plain load did NOT fault: the bug is present. */
  FAIL(2)

s_trap:
  /* ---- S-mode trap handler ---- */
  csrr t0, scause
  li t1, 21                 /* riscv::LOAD_GUEST_PAGE_FAULT */
  bne t0, t1, s_trap_fail   /* wrong cause: not the expected fault */
  la t3, stage
  ld t0, 0(t3)
  li t1, 1
  bne t0, t1, s_trap_fail   /* trapped before the hlvx had retired */
  /* The plain HLV raised the expected load guest-page fault: correct. */
  PASS

s_trap_fail:
  FAIL(127)
