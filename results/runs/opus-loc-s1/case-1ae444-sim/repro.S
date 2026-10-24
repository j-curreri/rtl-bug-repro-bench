#include "test.h"

/* With PMP granularity G=1 (8 bytes), a NAPOT entry must read back pmpaddr
 * exactly as written: only bits [G-2:0] (none here) read as ones. */
.globl test_main
test_main:
  /* Determine G: with entry OFF, write all ones and read back. */
  csrw pmpcfg0, zero
  li t0, -1
  csrw pmpaddr1, t0
  csrr t1, pmpaddr1
  andi t1, t1, 1
  bnez t1, done          /* G == 0: nothing to check */

  li t0, 0x20000000      /* NAPOT 16-byte region at 0x80000000 (bit0 = 0) */
  csrw pmpaddr1, t0
  li t1, 0x1800          /* pmp1cfg: A=NAPOT, no permissions */
  csrw pmpcfg0, t1
  csrr t2, pmpaddr1
  csrw pmpcfg0, zero
  bne t2, t0, fail
done:
  PASS
fail:
  FAIL(1)
