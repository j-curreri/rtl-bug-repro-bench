#include "test.h"

/* S-mode is not implemented, so mstatus.SXL (bits 35:34) must be read-only zero. */
  .text
  .globl test_main
test_main:
  li t1, (3 << 34)
  csrr t0, mstatus
  and t2, t0, t1
  bnez t2, fail1
  /* Attempt to set SXL; it must remain zero. */
  csrs mstatus, t1
  csrr t0, mstatus
  and t2, t0, t1
  bnez t2, fail2
  PASS
fail1:
  FAIL(1)
fail2:
  FAIL(2)
