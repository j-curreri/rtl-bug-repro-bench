/* Reproduce: MRET with mstatus.MPP=M and mstatus.MPV=1 must leave the hart in
 * non-virtualized M-mode. The spec ignores (and clears) MPV when MPP selects
 * M-mode, so the virtualization state V must be 0. The buggy core sets V=MPV=1,
 * leaving an inconsistent (virtualized) M-mode.
 *
 * The virtualization state is not directly readable, so we expose it:
 *   1. MRET back into M-mode with MPV set            -> (M, V=0) good / (M, V=1) bug
 *   2. SRET with HS sstatus.SPP=S and VS vsstatus.SPP=U
 *        good core (V=0): SRET uses the M/HS path -> lands in S-mode
 *        buggy core (V=1): SRET uses the VS path  -> lands in U-level (VU)
 *   3. Read an S-level CSR (sstatus)
 *        S-mode: allowed -> we PASS
 *        U-level: privilege violation -> traps to M-mode -> trap_handler FAILs
 */
#include "test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* S/U-level access for the PASS path (which runs in S-mode on a good core). */
  PMP_ALLOW_ALL

  /* Prime an MRET that returns to M-mode with mstatus.MPV set. */
  li   t0, (3 << 11)          /* mstatus.MPP = M */
  csrs mstatus, t0
  li   t0, 0x8000000000       /* mstatus.MPV = 1 (bit 39) */
  csrs mstatus, t0
  la   t0, post_mret
  csrw mepc, t0
  mret

  .align 2
post_mret:
  /* Good core: (M, V=0).  Buggy core: (M, V=1).
   * Convert the hidden virtualization state into a privilege difference with
   * a following SRET. SRET resumes from sepc (V=0) or vsepc (V=1) and picks the
   * new privilege from HS sstatus.SPP (V=0) or VS vsstatus.SPP (V=1). */
  csrci mstatus, 8           /* MIE off (defensive) */
  li   t0, 0x100            /* SPP bit */
  csrs sstatus, t0           /* HS sstatus.SPP = 1 (S) */
  csrc vsstatus, t0          /* VS vsstatus.SPP = 0 (U) */
  la   t0, post_sret
  csrw sepc, t0              /* SRET target when V=0 */
  csrw vsepc, t0             /* SRET target when V=1 */
  sret

  .align 2
post_sret:
  /* Good core: S-mode (V=0)   -> S-level CSR read succeeds -> PASS.
   * Buggy core: U-level (V=1) -> S-level CSR read traps -> FAIL. */
  csrr a0, sstatus
  PASS

  .align 2
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(1)
