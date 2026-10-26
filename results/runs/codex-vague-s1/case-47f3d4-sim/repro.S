#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* This configuration implements M and U, but no supervisor mode.
   * On RV64, mstatus.SXL (bits 35:34) must therefore be read-only zero.
   * The buggy RTL instead unconditionally forces SXL to XLEN_64 (2).
   */
  li t1, (3 << 34)
  csrr t0, mstatus
  and t0, t0, t1
  bnez t0, bad_initial_sxl

  /* Attempt to set both SXL bits; an absent S-mode must ignore this. */
  csrs mstatus, t1
  csrr t0, mstatus
  and t0, t0, t1
  bnez t0, bad_written_sxl

  csrc mstatus, t1
  csrr t0, mstatus
  and t0, t0, t1
  bnez t0, bad_written_sxl
  PASS

bad_initial_sxl:
  FAIL(1)
bad_written_sxl:
  FAIL(2)

  .balign 4
  .globl trap_handler
trap_handler:
  FAIL(127)
