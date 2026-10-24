#include "test.h"

  /*
   * Bug reproducer: mstatus reports an S-mode XLEN setting although S-mode is
   * not implemented.
   *
   * The core configuration cv64a6_imafdc_mu implements M-mode and U-mode only
   * (RVS=0, RVU=1, XLEN=64).  Per the RISC-V privileged spec, the XLEN control
   * field of an unimplemented privilege mode (here the SXL field of mstatus,
   * bits 35:34) must be read-only zero.  On this buggy core mstatus.SXL is
   * forced to XLEN_64, so it reads a non-zero value instead of 0.
   *
   * The test reads mstatus in M-mode and checks the SXL field.  A correct core
   * reads SXL == 0 -> PASS.  This core reads SXL != 0 -> FAIL.
   */
  .section .text
  .globl test_main
test_main:
  csrr  a0, mstatus        /* a0 = mstatus (64-bit) */
  srli  a0, a0, 34         /* bring SXL (bits 35:34) down to bits 1:0 */
  andi  a0, a0, 0x3        /* isolate the 2-bit SXL field */
  bnez  a0, sxl_not_zero   /* S-mode XLEN must read 0 on this core */
  PASS
sxl_not_zero:
  FAIL(1)
