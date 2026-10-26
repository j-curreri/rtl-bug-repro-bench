#include "test.h"

  .section .text
  .globl test_main
test_main:
  li t0, 0x40                 /* hstatus.GVA */
  csrw hstatus, t0
  csrr t1, hstatus
  andi t1, t1, 0x40
  bnez t1, fail_gva
  PASS

fail_gva:
  FAIL(1)

  .globl trap_handler
trap_handler:
  csrr t6, mcause
  FAIL(127)
