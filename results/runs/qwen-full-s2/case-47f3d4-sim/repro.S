#include "test.h"

  /* Reproducer for the mstatus SXLEN bug.
   *
   * This core (cv64a6_imafdc_mu) implements M-mode and U-mode but not S-mode
   * (CVA6Config.RVS = 0). The RISC-V privileged spec requires the XLEN control
   * field of mstatus for an unimplemented privilege mode to be read-only zero,
   * so on this core the SXLEN field must read 0.
   *
   * In core/csr_regfile.sv the csr_update block unconditionally executes
   *     if (CVA6Cfg.IS_XLEN64) begin
   *       mstatus_d.sxl = riscv::XLEN_64;
   *     ...
   * every cycle (it is outside the `if (csr_we)` guard, and IS_XLEN64 is a
   * constant), even though S-mode is not implemented. As a result this core
   * reports SXLEN = XLEN_64 (= 2) instead of 0.
   *
   * This core's mstatus field layout (riscv_pkg.sv mstatus_rv_t, RV64):
   *   SXLEN : bits [35:34]  mask 0xc00000000
   *   UXLEN : bits [33:32]  mask 0x300000000
   */

  .globl test_main
test_main:
  PMP_ALLOW_ALL

  csrr a0, 0x300              /* a0 = mstatus */

  /* Sanity check: U-mode is implemented on this RV64 core, so UXLEN
   * (bits [33:32]) must read XLEN_64 (= 2), i.e. 0x200000000. This confirms
   * the mstatus read is sane before we test the SXLEN field. */
  li   a1, 0x300000000        /* UXLEN field mask */
  and  a2, a0, a1
  li   a3, 0x200000000        /* UXLEN == XLEN_64 */
  bne  a2, a3, .Lbad_uxl

  /* The check: S-mode is unimplemented (RVS = 0), so SXLEN (bits [35:34])
   * must be read-only zero. Any non-zero value is the bug. */
  li   a1, 0xc00000000        /* SXLEN field mask */
  and  a2, a0, a1
  bnez a2, .Lbad_sxl

  PASS

.Lbad_uxl:
  FAIL(2)

.Lbad_sxl:
  FAIL(1)
