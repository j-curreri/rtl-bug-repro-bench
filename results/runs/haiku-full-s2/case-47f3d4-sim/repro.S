#include "test.h"

# Bug: mstatus.SXL reports XLEN (2 on RV64) although S-mode is not implemented.
# Per the privileged spec, SXL of an unimplemented mode is read-only zero.
# SXL is mstatus[35:34]. Read mstatus in M-mode and require SXL == 0.

.section .text.init
.globl test_main
test_main:
  csrr t0, mstatus
  srli t0, t0, 34
  andi t0, t0, 3
  bnez t0, 1f
  PASS
1:
  FAIL(1)
