#include "test.h"

/* Bug: mstatus.MBE is writable. This core only implements little-endian memory
 * accesses, so the spec requires MBE to be a read-only zero (WARL with a single
 * legal value). The buggy core keeps the written 1, which switches M-mode data
 * accesses to big-endian and makes the following stores fail on the bus. */

.section .text
.globl test_main
test_main:
  PMP_ALLOW_ALL

  # Try to set MBE (mstatus bit 37), then read mstatus back.
  li t0, (1 << 37)
  csrs mstatus, t0
  csrr t1, mstatus
  and t1, t1, t0
  bne t1, zero, 1f

  PASS
1:
  FAIL(2)
