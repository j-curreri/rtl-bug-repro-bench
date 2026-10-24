#include "test.h"
/* cv64a6_imafdc_mu has no S-mode (misa.S = 0). The privileged spec says
 * mstatus.SXL is then read-only zero; UXL must still be 2 (RV64 U-mode). */
.globl test_main
test_main:
  /* sanity: misa.S must be clear for the test to apply */
  csrr t1, misa
  srli t2, t1, 18
  andi t2, t2, 1
  bnez t2, pass

  /* SXL (mstatus[35:34]) must read zero */
  csrr t1, mstatus
  srli t2, t1, 34
  andi t2, t2, 3
  bnez t2, f1

  /* attempting to set SXL must leave it zero */
  li t0, (3 << 34)
  csrs mstatus, t0
  csrr t1, mstatus
  srli t2, t1, 34
  andi t2, t2, 3
  bnez t2, f2
pass:
  PASS
f1: FAIL(1)
f2: FAIL(2)
