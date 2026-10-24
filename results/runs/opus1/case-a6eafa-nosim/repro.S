/* Reproducer for: HLVX succeeds even when the VS-stage page table lives in
 * guest-physical memory that the G-stage maps execute-only.
 *
 * The implicit read of a VS-stage PTE is an ordinary load for G-stage
 * permission checks, so a G-stage execute-only (X, no R) mapping of the page
 * holding the VS-stage root table must raise a load guest-page fault.
 *
 * Setup (all 1 GiB leaves):
 *   G-stage  index 1 (GPA 0x40000000..) -> PA 0x80000000, EXECUTE-ONLY (X,!R,!W)
 *   G-stage  index 2 (GPA 0x80000000..) -> PA 0x80000000, RWX
 *   VS-stage index 2 (GVA 0x80000000..) -> GPA 0x80000000, RWX+U
 *
 * vsatp points at the VS root table through its guest-physical alias in the
 * execute-only G-stage window: GPA_vsroot = PA(vs_root) - 0x40000000, which
 * lands in G-stage index 1.  The very first step of the two-stage walk is the
 * G-stage translation of that vsatp root pointer (an implicit load).
 *
 *   correct core: G-stage lacks R on that page -> load guest-page fault -> PASS
 *   buggy core:   HLVX wrongly checks X for the implicit read -> walk completes
 *                 -> no trap -> FAIL(1)
 */
#include "hyp.h"

  .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* G-stage leaves: both alias physical DRAM at 0x80000000. */
  GIGA_LEAF(g_root, 1, 0x80000000, (PTE_V | PTE_X | PTE_U | PTE_A | PTE_D)) /* execute-only */
  GIGA_LEAF(g_root, 2, 0x80000000, G_RWX)

  /* VS-stage leaf: GVA 0x80000000 -> GPA 0x80000000 (RWX, user so VU may read). */
  GIGA_LEAF(vs_root, 2, 0x80000000, (VS_RWX | PTE_U))

  /* Turn on G-stage translation (hgatp, VMID 0). */
  HGATP_ON

  /* vsatp root = guest-physical alias of vs_root inside the execute-only
   * G-stage window (index 1): GPA = PA(vs_root) - 0x40000000. */
  la   t2, vs_root
  li   t3, 0x40000000
  sub  t2, t2, t3
  VSATP_ON(t2)

  /* Drop to HS-mode (V=0) to issue the hypervisor load. */
  ENTER_MODE(1, hs_entry)

hs_entry:
  li      a1, 0x80000000        /* guest virtual address */
  hlvx.wu a2, (a1)              /* must fault on a correct core */
  /* Only reached if the implicit VS-PTE read wrongly passed the G-stage check. */
  FAIL(1)

  /* Any guest-page fault (instr/load/store) from the walk means the core
   * correctly refused the execute-only implicit read. */
  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  li   t5, 20                   /* instruction guest-page fault */
  beq  t6, t5, _pass
  li   t5, 21                   /* load guest-page fault (expected) */
  beq  t6, t5, _pass
  li   t5, 23                   /* store/AMO guest-page fault */
  beq  t6, t5, _pass
  FAIL(127)
_pass:
  PASS

  HYP_TABLES
