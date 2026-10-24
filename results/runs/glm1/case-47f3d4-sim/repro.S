#include "test.h"

/*
 * Bug reproducer: mstatus reports an XLEN setting for an unimplemented
 * privilege mode.
 *
 * This configuration (cv64a6_imafdc_mu) implements M-mode and U-mode only:
 * RVS = 0 (core/include/cv64a6_imafdc_mu_config_pkg.sv). The privileged
 * specification requires the XLEN control field of an unimplemented
 * privilege mode to be read-only zero, so a compliant core must read
 * mstatus.SXL as 0.
 *
 * The bug: in csr_regfile.sv the assignment
 *     mstatus_d.sxl = riscv::XLEN_64;
 * is guarded only by CVA6Cfg.IS_XLEN64, not by CVA6Cfg.RVS, so it applies on
 * every clock and mstatus_q permanently latches SXL = 2 (SXLEN=64). Reading
 * mstatus in M-mode then shows a nonzero SXL.
 *
 * Test: read mstatus in M-mode and check the SXL field (bits 35:34 of the
 * 64-bit mstatus value in this core's layout, as in riscv::mstatus_rv_t;
 * note the neighbouring UXL field at bits 33:32 legitimately reads 2
 * because U-mode *is* implemented, so it is not part of the mask).
 * Zero (correct core) -> PASS, nonzero (buggy core) -> FAIL(1).
 */

  .globl test_main
test_main:
  csrr t1, mstatus      /* CRITICAL: read only, never write mstatus */
  srli t1, t1, 34
  andi t1, t1, 3        /* t1 = mstatus.SXL */
  beqz t1, ok
  FAIL(1)               /* SXL nonzero although S-mode is not implemented */
ok:
  PASS