#include "test.h"

/* Reproduce the mstatus.SXL bug on the cv64a6_imafdc_mu configuration.
 *
 * This core implements M-mode and U-mode but NOT S-mode
 * (cv64a6_imafdc_mu_config_pkg.sv: RVS=0, RVU=1, XLEN=64).
 *
 * The RISC-V privileged spec requires the XLEN control field of an
 * unimplemented privilege mode to be read-only zero. So for S-mode the
 * mstatus.SXL field must read 0b00.
 *
 * mstatus.SXL = bits [35:34]  (mask 0xC00000000)
 * mstatus.UXL = bits [33:32]  (mask 0x300000000)
 *
 * The buggy core (csr_regfile.sv) unconditionally forces mstatus.SXL =
 * XLEN_64 (0b10) on a 64-bit core, so the SXL field reads non-zero.
 *
 * test_main:
 *   - PASS  : SXL reads 0 (spec-compliant for a no-S-mode core)
 *   - FAIL(1): SXL reads non-zero (bug: S-mode XLEN reported)
 *   - FAIL(2): sanity - UXL does not read XLEN_64 as expected
 */

  .section .text
  .globl test_main
test_main:
  csrr t0, mstatus

  /* Bug check: S-mode is not implemented, so mstatus.SXL must read zero. */
  li   t1, 0xc00000000        /* SXL mask (bits 35:34) */
  and  t1, t0, t1
  bnez t1, 1f                 /* non-zero => S-mode XLEN is reported */
  j    2f
1:
  FAIL(1)
2:

  /* Sanity check: U-mode IS implemented and XLEN=64, so mstatus.UXL must
   * read XLEN_64 (0b10) => value 0x200000000 in the UXL field. This guards
   * against mstatus reading all-zero and makes the SXL/UXL contrast clear. */
  li   t1, 0x300000000        /* UXL mask (bits 33:32) */
  and  t1, t0, t1
  li   t2, 0x200000000        /* XLEN_64 placed in the UXL field */
  bne  t1, t2, 3f
  PASS
3:
  FAIL(2)
