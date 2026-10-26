#include "test.h"

  .section .text
  .globl test_main
test_main:
  /* 1. On a core without S-mode, mstatus.SXL (bits 35:34) must read as 0. */
  csrr t0, mstatus
  srli t1, t0, 34
  andi t1, t1, 3
  bnez t1, fail_init

  /* 2. Verify mstatus.SXL is read-only zero under writes (XLEN=64: 2'b10). */
  li   t2, 2
  slli t2, t2, 34
  csrs mstatus, t2
  csrr t0, mstatus
  srli t1, t0, 34
  andi t1, t1, 3
  bnez t1, fail_ro64

  /* 3. Verify mstatus.SXL is read-only zero under writes (XLEN=32: 2'b01). */
  li   t2, 1
  slli t2, t2, 34
  csrs mstatus, t2
  csrr t0, mstatus
  srli t1, t0, 34
  andi t1, t1, 3
  bnez t1, fail_ro32

  /* 4. Verify mstatus.SXL is read-only zero under writes (2'b11). */
  li   t2, 3
  slli t2, t2, 34
  csrs mstatus, t2
  csrr t0, mstatus
  srli t1, t0, 34
  andi t1, t1, 3
  bnez t1, fail_ro128

  PASS

fail_init:
  FAIL(1)
fail_ro64:
  FAIL(2)
fail_ro32:
  FAIL(3)
fail_ro128:
  FAIL(4)
