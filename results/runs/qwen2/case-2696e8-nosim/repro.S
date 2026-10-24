/* Bug reproducer for the cv64a6_imafdch_sv39 CVA6 core.
 *
 * Bug (reported): after an HLVX instruction reads from a guest page that the
 * G-stage maps execute-only, a plain HLV load from the same page also
 * succeeds.  An HLV must raise a load guest-page fault, because only HLVX
 * may treat execute permission as read permission.
 *
 * Root cause in this RTL: on a DTLB hit the data interface of cva6_mmu
 * re-checks only the U-bit of the cached G-stage PTE for loads; the
 * read-permission check (g_load_access_ok in cva6_mmu.sv) is computed but
 * never used.  Once an HLVX walk has filled the DTLB with an execute-only
 * G-stage PTE, a later plain HLV hits the DTLB and is not faulted.
 *
 * Setup (all in M-mode):
 *   G-stage (Sv39x4), root g_root:
 *     g_root[0]: GPA [0, 1 GiB)    -> HPA 0x80000000, execute-only
 *               (V|X|U|A|D) - the "data page".
 *     g_root[1]: GPA [1 GiB, 2 GiB) -> HPA 0x80000000, G_RWX - holds the
 *               VS-stage table (implicit PTE reads need G-stage read
 *               permission, so the VS table must live on a readable page).
 *   VS-stage (Sv39), root vs_root:
 *     vs_root[0]: GVA [0, 1 GiB) -> GPA [0, 1 GiB) identity leaf, R|W|X.
 *   hgatp -> g_root, hstatus.SPVP = 1,
 *   vsatp -> GPA of vs_root (in the g_root[1] window).
 *
 * Test (executed in HS-mode, so HLV/HLVX are legal and their loads are
 * translated with V=1 through VS-stage + G-stage):
 *   1. hlvx.wu from a GVA on the execute-only G page: succeeds on a correct
 *      core (execute permission may serve an HLVX read).  The walk caches
 *      the G-stage execute-only PTE in the DTLB.
 *   2. hlv.d from the same GVA: must raise a load guest-page fault
 *      (cause LOAD_GUEST_PAGE_FAULT = 21 in this core).
 *
 * Reporting (no S-mode data access is needed, and no mepc manipulation):
 *   - If hlv.d traps, the M-mode trap handler sees mcause == 21, confirms the
 *     hlvx.wu result (held in t0) matches the expected word (a1) and PASSes.
 *   - If hlv.d does not trap (buggy core), the test falls through to an
 *     S-mode ecall, reaching the M-mode handler with mcause == 9
 *     (ENV_CALL_SMODE).  The handler sees mcause != 21 and FAIL(2)s.
 */

#include "test.h"
#include "hyp.h"

#define LOAD_GUEST_PAGE_FAULT 21
#define ENV_CALL_SMODE        9

.section .data
known_val: .dword 0xAAAAAAAA55667788   /* low word 0x55667788 is the expected hlvx.wu result */
HYP_TABLES

.section .text
.globl test_main

test_main:
  PMP_ALLOW_ALL

  /* a0 = GVA of known_val: HPA(known_val) lies in the first 1 GiB G-page
   * window, which maps GPA -> HPA as 0x80000000 + GPA, and the VS stage is
   * an identity map, so GVA = HPA - 0x80000000. */
  la   a0, known_val
  li   t1, 0x80000000
  sub  a0, a0, t1
  /* a1 = expected word returned by hlvx.wu */
  li   a1, 0x55667788

  /* G-stage table */
  GIGA_LEAF(g_root, 0, 0x80000000, PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)
  GIGA_LEAF(g_root, 1, 0x80000000, G_RWX)
  /* VS-stage table: 1 GiB identity leaf at GPA 0 */
  GIGA_LEAF(vs_root, 0, 0, VS_RWX)

  /* enable G-stage translation with g_root */
  HGATP_ON

  /* guest effective privilege = S, so the VS-stage (non-U) and G-stage PTEs
   * pass their U-bit checks for the HLV loads below */
  li   t0, HSTATUS_SPVP
  csrs hstatus, t0

  /* point vsatp at the guest-physical address of vs_root, which lives in the
   * readable g_root[1] window so the MMU's implicit reads of the VS-stage
   * PTEs (GPA -> HPA via the G-stage) succeed */
  la   t0, vs_root
  li   t1, 0x80000000
  sub  t0, t0, t1
  li   t1, 0x40000000
  add  t0, t0, t1
  VSATP_ON(t0)

  /* enter HS-mode and run the guest test */
  ENTER_MODE(1, test_hs)

test_hs:
  /* a0 = GVA of known_val, a1 = expected word */
  hlvx.wu t0, 0(a0)        /* allowed: G-stage X may serve an HLVX read;
                             * fills the DTLB with the execute-only G PTE */
  hlv.d   t1, 0(a0)        /* must raise a load guest-page fault */
  ecall                   /* reached only if hlv.d did not trap -> buggy core */

/* M-mode trap handler: only the expected load guest-page fault may PASS */
.globl trap_handler
.align 2
trap_handler:
  /* integer registers are preserved across the trap: t0 holds the hlvx.wu
   * result and a1 the expected word, so verify the hlvx read was correct. */
  bne  t0, a1, unexp_trap
  csrr t2, mcause
  li   t3, LOAD_GUEST_PAGE_FAULT
  beq  t2, t3, pass_ok
  FAIL(2)                 /* mcause was an S-ecall (9): hlv.d did not trap */
pass_ok:
  PASS
unexp_trap:
  FAIL(127)
