#include "test.h"

/* Reproduce the S-mode XLEN bug in mstatus.
 *
 * This core is configured as cv64a6_imafdc_mu: it implements M-mode and
 * U-mode only, and does NOT implement S-mode (CVA6Config RVS = 0).
 *
 * The RISC-V privileged spec requires that the XLEN control field of an
 * unimplemented privilege mode be read-only zero.  Therefore, on a
 * spec-compliant core, mstatus.SXL must read back as 0.
 *
 * The buggy core unconditionally sets mstatus.SXL = XLEN_64 (2'b10) in
 * csr_regfile.sv.  In this core's mstatus register layout the SXL field
 * occupies bits [35:34] (the mstatus read data is the raw mstatus register,
 * so software observes SXL there).  Hence the buggy core reads
 * mstatus.SXL = 2 instead of 0.
 *
 * The test reads mstatus, isolates the SXL field, and PASSes only if it is
 * zero.  On the buggy core SXL != 0, so the test FAILs.
 */

  .globl test_main
test_main:
  csrr  a0, mstatus          /* a0 = raw mstatus value            */
  srli  a0, a0, 34           /* move SXL (bits 35:34) to bit 1:0  */
  andi  a0, a0, 0x3          /* a0 = SXL field (2 bits)           */
  bne   a0, zero, .Lsxl_bug  /* SXL != 0  ->  unimplemented mode  */
                              /* must not report an XLEN setting  */
  PASS                       /* SXL == 0 -> correct per spec      */

.Lsxl_bug:
  FAIL(1)                    /* SXL is non-zero: S-mode XLEN bug  */
