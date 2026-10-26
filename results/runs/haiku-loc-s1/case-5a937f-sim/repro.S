#include "test.h"

/* medeleg bit 9 is "environment call from S-mode". Only bit 11 (M-mode ecall) is
 * read-only zero in medeleg, so bit 9 must be writable and read back as written.
 * The buggy csr_regfile.sv leaves bit 9 out of the MEDELEG write mask, so it stays 0. */
  .section .text
  .globl test_main
test_main:
  li t0, -1
  csrw medeleg, t0
  csrr t1, medeleg
  li t2, (1 << 9)
  and t1, t1, t2
  beqz t1, 1f
  PASS
1:
  FAIL(1)
