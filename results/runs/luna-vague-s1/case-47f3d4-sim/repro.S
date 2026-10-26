#include "harness/test.h"

  .section .text
  .align 2
  .globl test_main
test_main:
  /* MPP has two bits at [12:11].  This core implements M and U, but not S. */
  csrr t0, mstatus
  li   t1, ~(3 << 11)
  and  t0, t0, t1
  li   t1, (3 << 11)          /* Establish a known, supported prior value. */
  or   t0, t0, t1
  csrw mstatus, t0

  csrr t0, mstatus
  li   t1, ~(3 << 11)
  and  t0, t0, t1
  li   t1, (1 << 11)          /* Request unsupported S-mode. */
  or   t0, t0, t1
  csrw mstatus, t0

  csrr t0, mstatus
  srli t0, t0, 11
  andi t0, t0, 3
  bnez t0, fail_bad_mpp       /* Supported least privilege is U (0). */
  PASS

fail_bad_mpp:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(127)
