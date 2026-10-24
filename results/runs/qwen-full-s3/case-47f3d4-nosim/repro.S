/*
 * Bug reproducer: mstatus.SXL must read as zero.
 *
 * This core is configured cv64a6_imafdc_mu (rv64, M-mode + U-mode only, no
 * S-mode: config RVS=0).  The RISC-V privileged spec requires the XLEN
 * control field of an *unimplemented* privilege mode to be read-only zero,
 * so mstatus.SXL (bits 35:34) must always read 0.
 *
 * The buggy core instead forces mstatus.SXL = XLEN_64 (2'b10, bit 35 set)
 * on every commit (core/csr_regfile.sv), so reading mstatus yields a
 * non-zero SXL field.
 *
 *   Correct core: mstatus[35:34] == 0  -> PASS
 *   Buggy core:   mstatus[35:34] != 0  -> FAIL
 */
#include "test.h"

  .section .text
  .globl test_main
test_main:
  csrr  t0, mstatus        /* read mstatus */
  srli  t0, t0, 34         /* move SXL (bits 35:34) down to bits 1:0 */
  andi  t0, t0, 0x3        /* isolate the 2-bit SXL field */
  bnez  t0, .Lsxl_bad      /* SXL non-zero => bug */
  PASS
.Lsxl_bad:
  FAIL(42)
