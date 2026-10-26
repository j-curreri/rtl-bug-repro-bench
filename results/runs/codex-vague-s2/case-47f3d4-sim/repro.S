#include "test.h"

/*
 * This RV64 configuration implements M and U modes, but no S mode.
 * The privileged specification requires mstatus.SXL (bits 35:34) to
 * be read-only zero when S-mode is not supported.  In the buggy RTL,
 * csr_regfile instead unconditionally forces SXL to XLEN_64 (2).
 */
  .section .text
  .balign 4
  .globl test_main
test_main:
  /* Clearing SXL must leave it reading zero. */
  li t0, (3 << 34)
  csrc mstatus, t0
  csrr t1, mstatus
  and t1, t1, t0
  bnez t1, fail_clear

  /* Trying to set SXL to the RV64 encoding must also read back zero. */
  li t1, (2 << 34)
  csrs mstatus, t1
  csrr t1, mstatus
  and t1, t1, t0
  bnez t1, fail_set

  PASS

fail_clear:
  FAIL(1)
fail_set:
  FAIL(2)

  .balign 4
  .globl trap_handler
trap_handler:
  FAIL(127)
