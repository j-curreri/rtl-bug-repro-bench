/*
 * Bug reproducer: mstatus reports SXL != 0 on a core without S-mode.
 *
 * According to RISC-V Privileged Architecture (Section 3.1.6):
 * "When a privilege mode is not supported, the associated XLEN field
 *  is read-only zero."
 *
 * On this core configuration (cv64a6_imafdc_mu), S-mode is unimplemented
 * (RVS = 0). Therefore, mstatus.SXL (bits 35:34) must be read-only zero.
 * However, the buggy core unconditionally initializes mstatus.SXL to 2
 * (XLEN_64).
 */

#include "test.h"

  .globl test_main
test_main:
  csrr t0, mstatus
  srli t0, t0, 34
  andi t0, t0, 3
  bnez t0, 1f
  PASS
1:
  FAIL(1)
