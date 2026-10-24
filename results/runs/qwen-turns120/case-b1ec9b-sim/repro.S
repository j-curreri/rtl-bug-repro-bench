#include "test.h"

  /*
   * Bug: The RISC-V privileged spec requires that an MRET returning from M-mode
   * to a less-privileged mode (here S-mode) clears mstatus.MPRV.  In this core
   * the MPRV-clear on MRET is gated behind the hypervisor extension (CVA6Cfg.RVH)
   * in csr_regfile.sv, but cv64a6_imafdc_sv39 has RVH disabled, so MPRV is never
   * cleared.  After such an MRET, software that later runs in M-mode sees memory
   * accesses still translated/permission-checked as if MPRV were in effect (the
   * load/store PMP check uses MPP instead of M because ld_st_priv_lvl = MPP when
   * MPRV is set).
   *
   * Test: grant S/U memory access (PMP default-deny otherwise), then in M-mode
   * set MPP=S and MPRV=1 and MRET into S-mode (which must clear MPRV).  From
   * S-mode trap back to M-mode with an ecall so we can inspect the M-mode-only
   * mstatus CSR.  A conforming core now has MPRV==0 -> PASS.  This buggy core
   * keeps MPRV==1 -> FAIL.
   */

#define MPP_MASK   (3 << 11)   /* mstatus.MPP field (bits 12:11) */
#define MPP_S      (1 << 11)   /* MPP = 01 (S-mode) */
#define MPRV_BIT   (1 << 17)   /* mstatus.MPRV */

  .section .text
  .globl test_main
test_main:
  /* Allow S/U-mode code to run: PMP default-deny would otherwise block it. */
  PMP_ALLOW_ALL

  /* Put MPP into a known state, then establish MPP=S and MPRV=1. */
  li   t0, MPP_MASK
  csrc mstatus, t0
  li   t0, (MPP_S | MPRV_BIT)
  csrs mstatus, t0
  /* MRET into S-mode.  A conforming core clears MPRV on this MRET. */
  la   t0, s_entry
  csrw mepc, t0
  mret

  .align 2
s_entry:
  /* Now in S-mode; MPRV should already be 0.  mstatus is an M-mode CSR, so trap
   * back to M-mode with an S-mode ecall to observe MPRV there. */
  ecall

  /*
   * trap_handler is installed by _start (mtvec).  The S-mode ecall lands here in
   * M-mode; the trap does not modify MPRV, so it still reflects the MRET-to-S.
   */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t0, mstatus
  li   t1, MPRV_BIT
  and  t1, t0, t1
  bnez t1, fail_mprv      /* MPRV still set after MRET to S -> buggy core */
  PASS
fail_mprv:
  FAIL(1)
