#include "test.h"

  .section .text
  .balign 4
  .globl test_main
test_main:
  /* RV64 mstatus.SXL occupies bits 35:34.  With no S-mode it must
     be read-only zero; UXL (bits 33:32) is independent. */
  li t0, (3 << 34)
  csrr t1, mstatus
  and t1, t1, t0
  bnez t1, bad_initial_sxl

  /* CSR read/modify/write operations preserve the other status fields. */
  csrc mstatus, t0
  csrr t1, mstatus
  and t1, t1, t0
  bnez t1, bad_clear_sxl

  csrs mstatus, t0
  csrr t1, mstatus
  and t1, t1, t0
  bnez t1, bad_set_sxl

  PASS

bad_initial_sxl:
  FAIL(1)
bad_clear_sxl:
  FAIL(2)
bad_set_sxl:
  FAIL(3)

  .balign 4
  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(127)
