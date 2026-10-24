#include "test.h"

/* Reproducer: mstatus reports an XLEN setting for S-mode although this core
 * implements M and U mode but NOT S-mode.
 *
 * This config (cv64a6_imafdc_mu) has RVS=0 (no S-mode) and XLEN=64.  Per the
 * RISC-V privileged spec, the XLEN control field of an *unimplemented*
 * privilege mode must be read-only zero.  Here that field is SXL.
 *
 * The buggy RTL hardwires the field:
 *     core/csr_regfile.sv:  if (IS_XLEN64) begin
 *                              mstatus_d.sxl = riscv::XLEN_64;   // <-- BUG
 *                              mstatus_d.uxl = riscv::XLEN_64;
 *                           end
 * so a read of mstatus returns a non-zero SXL even though S-mode does not
 * exist.  UXL is legitimately XLEN_64 (U-mode is implemented, RVU=1) and is
 * therefore *not* the bug.
 *
 * In this core's mstatus layout SXL occupies bits [35:34]
 *   (see riscv_pkg.sv: mstatus_sxl = {28'h0, sxl, sxl, 34'h0})
 * so the SXL mask is 0xC00000000 (bits 35 and 34).
 *
 * Correct core : SXL == 0  -> PASS
 * Buggy core   : SXL != 0  -> FAIL
 */

  .globl test_main
test_main:
  csrr  t0, mstatus
  li    t1, 0xC00000000        /* mask for SXL = mstatus[35:34] */
  and   t0, t0, t1
  bnez  t0, sxl_not_zero       /* SXL must be zero when S-mode is unimplemented */
  PASS

sxl_not_zero:
  FAIL(1)

  /* Safety net: any trap that reaches the handler is an unexpected failure.
   * (The harness default handler also fails; we override it to keep a
   * distinct error code.) */
  .globl trap_handler
  .align 2
trap_handler:
  csrr t6, mcause
  FAIL(2)
