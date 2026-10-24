/* Reproducer for the CVA6 cv64a6_imafdc_mu mstatus.SXL bug.
 *
 * Configuration facts (core/include/cv64a6_imafdc_mu_config_pkg.sv):
 *   XLEN = 64, RVS = 0 (no S-mode), RVU = 1, no H extension.
 *
 * Bug (core/csr_regfile.sv, "csr_update" always_comb):
 *
 *     if (CVA6Cfg.IS_XLEN64) begin
 *       mstatus_d.sxl = riscv::XLEN_64;   <-- no CVA6Cfg.RVS guard
 *       ...
 *     end
 *
 *   This sits OUTSIDE the `if (csr_we)` write block, so it executes on every
 *   clock cycle and forces mstatus.SXL (bits 35:34) to 2'b10 regardless of
 *   what (or whether anything) is written.  S-mode is not implemented in this
 *   configuration, and the privileged spec requires the XLEN control field of
 *   an unimplemented privilege mode to be read-only ZERO.  A spec-conformant
 *   version of this core therefore reports mstatus.SXL == 0 at all times.
 *   (The U-mode field UXL, bits 33:32, is likewise forced to 2, but U-mode is
 *   implemented here so that value is legal and must NOT be checked.)
 *
 * Discriminator: read mstatus and check bits 35:34 (SXL) are zero, then try
 * to set an SXL bit with a CSR write and check it is still zero on read-back.
 * Both checks only pass on spec-conformant RTL.
 *
 * Everything runs in M-mode; no trap is expected on either core, and the
 * harness default trap_handler turns any unexpected trap into a failure.
 */

#include "test.h"

  .globl test_main
test_main:
/* ---- Check 1: mstatus.SXL must read zero (S-mode unimplemented) -------- */
  csrr t0, mstatus
  li t1, 3
  slli t1, t1, 34           /* SXL mask: bits 35:34 = 0xC00000000 */
  and t2, t0, t1
  bnez t2, fail_sxl_read

/* ---- Check 2: SXL is read-only zero -> a write cannot make it stick ---- */
  csrr t0, mstatus
  li t1, 1
  slli t1, t1, 34           /* try to set the high bit of the SXL field */
  or t0, t0, t1
  csrw mstatus, t0
  csrr t0, mstatus
  li t1, 3
  slli t1, t1, 34
  and t2, t0, t1
  bnez t2, fail_sxl_write

/* Both checks passed on this core -> shut down with success. */
  PASS

fail_sxl_read:
  FAIL(1)

fail_sxl_write:
  FAIL(2)