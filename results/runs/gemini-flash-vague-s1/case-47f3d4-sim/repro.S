#include "test.h"

  .globl test_main
test_main:
  // On this configuration (cv64a6_imafdc_mu), S-mode is not implemented.
  // According to the RISC-V Privileged Architecture Specification (Section 3.1.6.2):
  // "When a lower privilege mode is not supported, the corresponding SXL or UXL
  // field is read-only zero."
  // Therefore, mstatus.SXL (bits 35:34) must be read-only zero.

  // 1. Initial value check: SXL must be zero.
  csrr t0, mstatus
  srl  t0, t0, 34
  andi t0, t0, 3
  bnez t0, fail

  // 2. Read-only check: attempting to write non-zero to SXL must be ignored.
  li   t1, 3
  slli t1, t1, 34
  csrs mstatus, t1
  csrr t0, mstatus
  srl  t0, t0, 34
  andi t0, t0, 3
  bnez t0, fail

  PASS

fail:
  FAIL(1)
