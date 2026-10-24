#include "test.h"
/* cv64a6_imafdc_mu has no S-mode (RVS=0). Per the privileged spec,
 * mstatus.SXL (bits 35:34) must then be read-only zero. */
.globl test_main
test_main:
  csrr t1, mstatus
  srli t2, t1, 34
  andi t2, t2, 3
  bnez t2, fail_sxl
  PASS
fail_sxl:
  FAIL(1)
