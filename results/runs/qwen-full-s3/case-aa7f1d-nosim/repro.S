/*
 * Bug reproducer: MRET with mstatus.MPP=M and mstatus.MPV=1.
 *
 * The spec says MPV is ignored when MRET returns to M-mode. This core instead
 * unconditionally sets the virtualization bit v from MPV on MRET
 * (csr_regfile.sv, MRET path:  v_d = mstatus_q.mpv;). So an MRET to M-mode
 * with MPV=1 leaves the buggy hart in M-mode with v=1, an inconsistent state
 * (M-mode with the virtualization bit set).
 *
 * To observe the residual v: after that MRET both cores sit in M-mode, but the
 * buggy one additionally has v=1. Executing SRET then behaves differently:
 *   - v=0 (correct core): SRET returns to sepc,  priv <- mstatus.SPP
 *   - v=1 (buggy core):   SRET returns to vsepc, priv <- vsstatus.SPP
 * (csr_regfile.sv: epc_o = (RVH && v_q) ? vsepc : sepc, plus the sret&&v_q /
 *  sret&&!v_q state blocks that pick the privilege level.)
 *
 * We point sepc at a path that PASSes and vsepc at a path that FAILs:
 *   correct core -> sepc  -> good -> PASS
 *   buggy   core -> vsepc -> bad  -> FAIL
 * No page tables are enabled (satp/vsatp left Bare), so every address is a
 * physical address and PMP_ALLOW_ALL lets code run at any privilege level.
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  PMP_ALLOW_ALL

  /* --- Trigger the bug: MRET back to M-mode with MPV set --- */
  la   t0, after_mret
  csrw mepc, t0
  li   t0, 3
  slli t0, t0, 11          /* mstatus.MPP = M (0b11 in bits 12:11) */
  li   t1, 1
  slli t1, t1, 39          /* mstatus.MPV = bit 39 */
  or   t0, t0, t1
  csrs mstatus, t0
  mret

after_mret:
  /* Both cores are in M-mode here; the buggy one is additionally in
   * virtualization mode (v=1). Prepare SRET so the two cores diverge:
   *   correct (v=0) -> sepc    = good -> PASS
   *   buggy   (v=1) -> vsepc   = bad  -> FAIL */
  li   t0, 0x100           /* SPP bit (bit 8) */
  csrc mstatus, t0         /* mstatus.SPP  = U */
  csrc vsstatus, t0        /* vsstatus.SPP = U */
  la   t0, good
  csrw sepc, t0
  la   t0, bad
  csrw vsepc, t0
  sret

good:
  PASS

bad:
  FAIL(1)
