/*
 * Bug reproducer: mstatus.SXL reports a nonzero XLEN even though S-mode is
 * not implemented.
 *
 * Config cv64a6_imafdc_mu: M-mode + U-mode only, no S-mode (RVS=0), XLEN=64.
 * The RISC-V privileged spec requires the SXL field of mstatus to be
 * read-only zero when supervisor mode is not implemented. On this core the
 * mstatus next-state logic (csr_regfile.sv) unconditionally forces SXL to
 * XLEN_64 (2'b10) on every cycle, so mstatus.SXL reads 2 instead of 0.
 *
 * In this core's mstatus register layout (see riscv::mstatus_rv_t in
 * core/include/riscv_pkg.sv), SXL occupies bits [35:34].
 *
 *   correct core: mstatus & 0x000000C000000000 == 0 -> PASS
 *   buggy  core:  mstatus & 0x000000C000000000 != 0 -> FAIL(1)
 */
#include "test.h"

.globl test_main
test_main:
  csrr t0, mstatus                  /* read mstatus in M-mode */
  li   t1, 0x000000C000000000        /* SXL field mask (bits [35:34]) */
  and  t1, t0, t1
  beqz t1, sxl_is_zero
  FAIL(1)                           /* S-mode unimplemented but SXL != 0 */
sxl_is_zero:
  PASS
