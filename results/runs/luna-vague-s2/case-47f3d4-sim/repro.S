#include "test.h"

  .section .text
  .globl test_main
  .align 2
test_main:
  /* MPP supports U and M in this configuration.  S (01) is unsupported,
   * so a write of that encoding must be coerced to the least supported
   * privilege mode, U (00). */
  csrr t0, mstatus
  li   t1, -6145              /* ~0x1800: clear MPP[12:11] */
  and  t0, t0, t1
  li   t1, 0x1800             /* establish a known previous value: M */
  or   t0, t0, t1
  csrw mstatus, t0

  csrr t0, mstatus
  li   t1, -6145
  and  t0, t0, t1
  li   t1, 0x800              /* unsupported S encoding */
  or   t0, t0, t1
  csrw mstatus, t0

  csrr t0, mstatus
  li   t1, 0x1800
  and  t0, t0, t1
  bnez t0, fail_mpp
  PASS

fail_mpp:
  FAIL(1)

  .globl trap_handler
  .align 2
trap_handler:
  FAIL(2)
